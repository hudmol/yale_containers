Yale Containers
===============

ArchivesSpace plugin to add a new container type to ArchivesSpace.
More information on these at
http://campuspress.yale.edu/yalearchivesspace/2014/11/20/managing-content-managing-containers-managing-access/.

## Installing it

To install, just activate the plugin in your config/config.rb file by
including an entry such as:

     # If you have other plugins loaded, just add 'yale_containers' to
     # the list
     AppConfig[:plugins] = ['local', 'other_plugins', 'yale_containers']
     
And then clone the `yale_containers` repository into your
ArchivesSpace plugins directory.  For example:

     cd /path/to/your/archivesspace/plugins
     git clone https://github.com/hudmol/yale_containers.git yale_containers


## Upgrading from a previous release

Each release of this plugin comes with some database schema changes
that need to be applied.  To upgrade from a previous release:

  1. Replace your `/path/to/archivesspace/plugins/yale_containers`
     directory with the new release version
     
  2. Run the database setup script to update all tables to the latest
     version:
     
          cd /path/to/archivesspace
          scripts/setup-database.sh
