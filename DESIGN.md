
# Design Notes


## Uploading

let manager = Manager(local_identifier: "my-local-db")

let local_journal = manager.journal(identifier: "my-local-db")
let journal_name = "my-local-db.journal"

sync_manager.upload(journal: local_journal)

## within sync_manager upload()

let remote_timestamp = remote_timestamps[local_journal.identifier]
let new_timestamp = local_journal.timestamp
if new_timestamp > remote_timestamp {
    dropbox.upload(remote_file: "/journals/\(journal_name)", local_data: local_journal) { success in
      remote_timestamps[local_journal.identifier] = new_timestamp 
    }
}

## Download/Sync

// First, download all the files that are needed

var files_to_download = []
dropbox.get_file_metadata(remote: "/journals") { metadata in
    foreach journal in manager.journals() {
        let journal_filename = journal.identifier + ".journal"
        let local_timestamp = local_metadata[journal_filename].timestamp
        let remote_timestamp = metadata[journal_filename].timestamp
        if local_timestamp < remote_timestamp {
            files_to_download.append(journal_filename)
        }
    }
}

dropbox.download(files: files_to_download) { files in
    let journals = files.map({ journal_from_file($0) })
    manager.merge(journals: journals)
}

## Change entries

manager.update(identifier: identifier, properties: properties)

## Listening for changes

manager.add(observer: observer)

enum MoveType {
    case moveBefore
    case moveAfter
    case moveToTop
    case moveToBottom
}

struct SortEvent {
    let identifier: String
    let siblingIdentifier: String
    let moveType: MoveType
}

struct Update {
    let identifier: String
    let properties: [String : String]
    let timestamp: Date

    // Given a journal, create a single update command
    init(journal: Journal)
}

protocol ManagerEventObserver {
    func manager(manager: Manager, didUpdate entityUpdates: [Update])
    func manager(manager: Manager, didSortItems: [SortEvent])
}

struct Journal {
    let identifier: String
    let updates: [Update] 
}

struct Entity {
    let identifier: String
    let properties: [String : String]

    // An array of all the identifiers that have been applied to this entity to make it what it is,
    // in timestamp order
    let update_identifiers: [String]

    // Create a new entity from a journal of changes ONLY for that entity
    init(identifier: String, journal: [Journal])
}

struct ManagerState {
    let local_identifier: String

    let journals: [Journal]

    // All journals split up and updates sorted by time 
    let entity_journals: [String : Journal]
}

struct DatabaseState {
    let entities: [String : Entity]
}

class Manager {
    var state: ManagerState
    var database_state: DatabaseState

    func journal(identifier: String) -> Journal
    func journals() -> [Journal]

    func update(identifier: String, properties: [String : String])

    func add(observer: ManagerEventObserver)

    func merge(journals: [Journal]) {
        var temporary_entity_journals: [String : Journal]

        let journals_with_deltas_only = /* take journals and using state.journals, keep only the new updates */
        // TODO: update state.journals and replace each one with the newer contents in journals

        // Split up the journals into changes per entity
        for journal in journals_with_deltas_only {
            for update in journal.updates {
                let old_journal = temporary_entity_journals[update.identifier] ?? []
                // Take an update and insert it into the old_journal, ensuring the sort order is correct
                let new_journal = insert_in_order(journal: old_journal, update: update)
                temporary_entity_journals[update.identifier] = new_journal
            }
        }

        // Now go through all the changes found and merge them with existing ones in DatabaseState
        // 1st: if the updates all come after the old ones, append and play back the entry
        // 2nd: if updates are intermingled, then must play back the entry from the start

        foreach in temporary_entity_journals { key, value in
            let entity_id = key
            let new_journal = value
            let old_journal = state.entity_journals[entity_id]

            let old_entity = database_state.entities[entity_id]
            if old_journal.last.timestamp < new_journal.first.timestamp {
                // It's just an append operation...
                let update = Update(journal: new_journal)

                // Take an update and apply it to our database AND send out events
                self.apply_update_to_entity(update)

                // TODO: update the entity's update_identities

                // append new journal and store it
                state.entity_journals[entity_id] = old_journal + new_journal
            } else {
                let merged_journal = merge_journals(first: old_journal, second: new_journal)

                // create a replacement entity 
                let entity = Entity(identity: merged_journal.first.identity, journal: merged_journal)

                // Take existing entity and swap in the new one.
                // - send any events for changes that result from the new entity updating one or more properties 
                //   of the old one...
                self.replace_entity(entity: entity)

                state.entity_journals[entity_id] = merged_journal
            }
        }
    }

    init(local_identifier: String) {
    }

    // Serialize to a file
    func save(to filename: String) {
        // Basically
        // - save database_state
        // - save state
    }
}

