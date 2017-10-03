
# What is SlouchDB?

SlouchDB is a database for Mac and iOS that provides a server-less solution for multi-client, single-user 
applications that wish to synchronize data across the multiple clients.

Basically, it lets you sync data across multiple clients with only a file storage service, like Dropbox or OneDrive.

# Why?

I was writing a to-do app for Mac and iOS and wanted to sync the data across the two clients but I didn't
want to write a cloud sync service. Instead, I just used Dropbox to host my files but needed a way to
synchronize information without requiring locks on the files.

# How does it work?

A single client is responsible for its own database state. As entries are inserted and updated in the local database,
a journal of diffs is written to locally. When it comes to time to sync the data with the other clients, the client
uploads the local journal of diffs to the remote file store. It also downloads any journal files that other clients 
have uploaded to the remote file store. The local and remote journals are then merged and the merged journal is 
played back to create the database state. Diff entries are timestamped and played back in chronological order.

Each client is responsible for writing to its own journal file and for uploading this file to the remote store. This
ensures that no locking mechanisms are required on the shared files. Furthermore, merge conflicts are handled by 
having the latest change win. 

Diffs can make changes to individual properties of a given database entry.

Database entries are simply key-value pairs where the key is a string the value is a JSON type. (At the moment, the
only value types allowed are strings themselves, but this will be expanded to include any JSON type in a future
change.)

# Optimizations

SlouchDB takes care of intelligently managing the merging of the journal files and managing local 
edits to the local journal. An external sync engine which pulls down remote journal files and pushes
up the latest local journal file is not provided. However, there is an illustration of how such a sync
engine could work in the provided example project. (There are plans to spin this out into a 
full-fledged cloud sync using Dropbox. For now, the example will suffice.)

# Limitations

SlouchDB is meant for single-user scenarios. This is important because it assumes that at any one time, diffs will
be coming from only one source. This avoids any issues about conflicts across two clients. If a user makes a change
on device A and then moves to device B and makes the change, the change on device B will win because it happens
later. If there are two different users making changes, they may not expect such behavior.

