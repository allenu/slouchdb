
# Summary

This example project is meant to illustrate how to use SlouchDB from a client app.

The app lets you create a list of people, each with a name, weight, and age. The list of people is
saved to a document. You can create several of these documents independently, each with their own
list.

You can edit each field in the table (name, weight, age) by double-clicking and entering a new value.

Hit cmd-S to save the document.

## Syncing

You can also sync the list of people in each document with other documents by selecting a sync
folder. First click "Select Folder" and select the SampleSync folder found in SlouchDB_Example.
Then click "Sync" to sync against the journals found SampleSync. Your document will start to
populate with sample contents found in the journals.

If you had made any edits to this current document, those edits will be saved to a journal file
and copied to the SampleSync folder as well. If you open up a second document and do the same
sync operation, it will pull in the changes that came from the first document.

You may inspect the .journal files in the SampleSync folder to see the make-up of the files. They're
simply JSON files containing diff entries.

## Cycling

Each document has a current "local identifier". This is simply a UUID that is used to uniquely 
create a journal for the local client. When the contents of the document are synced, a .journal
file is created with the UUID as the filename prefix. As an optimization, the local identifier
can be "cycled", which simply means assigning a brand new UUID to the current document. Any
previous journals created with an old local identifier UUID will remain intact locally and on
any sync folders that were previously synced to. 

The purpose of cycling is to start a new .journal file. This could come in handy if a journal file
gets too large and you wish to start a new one. This is most useful once remote cloud file syncing
is working as it would mean over time you would not need to upload or download as many changes.
Imagine a journal got very large, whenever any small change was made to it, it would be need to
be uploaded completely. However, if instead we broke it up into several smaller files, only the
latest journal file would need to be uploaded.

# Limitations

This sample project is an illustration and also a simple test to see how well SlouchDB could be
used. There are a few limitations, however.

1. Entries can't be deleted. SlouchDB uses a model where entries can only be created and modified
over time. They can't be deleted. However, it can be possible to simulate this by adding a "deleted"
flag. This would require a client that is able to filter its fetch results based on deleted state
so as not to show any deleted items.

2. Sort order. SlouchDB doesn't impose a sort order on the entries. It simply stores key-value
pairs. The fetching could also be improved to auto-sort these results efficiently.

Overall, it would be possible to make deletion and sort order work by using a "view" system to
filter the results intelligently. A view would provide a nice front-end that takes care of 
re-ordering entries, hiding deleted items and so on.

# Implementation Details

## Serialization

The database "state" is made up of three parts:

- the current state of all objects (i.e. property dictionaries)
- the individual histories of the objects -- the chronological diffs that make up their current state
- the set of journals we've processed to create the individual histories above

A client will also have an additional piece of information: its journal identifier.

### Objects

This is stored as a JSON dictionary, where each key is the object identifier and the value is a dictionary
of properties.

### Object Histories

This is a JSON dictionary, where each key is the object identifier and the value is a dictionary where
currently the lone entry is a key of "df" and the value is an array of diffs that represent the diffs
that make up the current object state. These are listed in chronological order from oldest to newest.

### Journals

This is a JSON dictionary, each each key is the journal identifier and the value is a dictionary
where currently the lone entry is a key of "df" and the value is an array of diffs that represent
the diffs that make up that journal. Unlike an object history, each diff has an additional 
property "_id" which represents the the object identifier to which this diff applies.

