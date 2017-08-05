# === for sqlite3 gem
sudo apt install libsqlite3-dev 

# === for sqlitebrowser (to view the sqlite db)
sudo add-apt-repository -y ppa:linuxgndu/sqlitebrowser
sudo apt update
sudo apt install sqlitebrowser



# === for spatialite (v4.3.0a-5 on Ubuntu 16.10.3 (kubuntu x64))

# sudo apt install libspatialite7
# => /usr/lib/x86_64-linux-gnu/libspatialite.so.7.1.0
# # ^ don't need this for Ruby-level support.
# #   mod-spatialite .so seems to contain all necessary symbols.

sudo apt install libsqlite3-mod-spatialite # needed to load into sqlite
# =>/usr/lib/x86_64-linux-gnu/mod_spatialite.so.7.1.0
