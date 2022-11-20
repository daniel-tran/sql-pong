# SQL Pong

An experimental version of Pong that's playable using only database tables and functions.

```
INFO:  P1: 1, P2: 0


==================



#
#           @    #
#                #
                 #


==================
```

# Features

- Supports 2 players or 1 player vs. a CPU controlled opponent.
- Adjustable CPU behaviour with two possible difficulty modes.
- Can interchangeably switch between players in 1 player mode. Now you can play both sides so that you always come out on top!

# Install

1. Install PostgreSQL. You may also want to install pgAdmin as well during the installation, though not strictly necessary.
2. Setup your master password and initial database.
3. If you installed pgAdmin during the installation of PostgreSQL, go to step 4. Otherwise, go to step 5.
4. In pgAdmin, log into your initial database and open the Query Tool. Press the "Open File" button and select pong.sql. Press the "Execute/Refresh" button once the file as loaded in the Query Tool. Afterwards, go to step 6.
5. Run the following command, replacing the items in angle brackets with the appropriate values for your environment:

```bash
psql.exe --dbname=<database name> --port=<PostgreSQL port provided during installation> --username=<user with access to database> --no-align --field-separator="" --tuples-only --file=<directory of sql-pong repo>\pong.sql
```

Note that you may get some NOTICE level messages about certain tables not existing - These can be safely ignored at this stage.
6. Once you get an initial output of the game screen, the installation of SQL Pong is deemed successful.

# How to play (using pgAdmin)

This game as been confirmed to be working using pgAdmin 4 version 6.14, though a later version should work as well.

## 2P Mode

Run the following command in the Query Tool:

```sql
SELECT pong.playGameWithTwoPlayers(0, 0); SELECT * FROM pong.printScreen();
```

Modify the two function parameters to move the players accordingly.

## 1P Mode (Left Side)

Run the following command in the Query Tool:

```sql
SELECT pong.playGameWithOnePlayer(1, 0); SELECT * FROM pong.printScreen();
```

Modify the second function parameter to move the left side player accordingly.

## 1P Mode (Right Side)

Run the following command in the Query Tool:

```sql
SELECT pong.playGameWithOnePlayer(2, 0); SELECT * FROM pong.printScreen();
```

Modify the second function parameter to move the right side player accordingly.

# How to play (using psql.exe)

This game as been confirmed to be working using psql version 15.0, though a later version should work as well.

Users choosing the play using psql.exe should have either set up the [PGPASSWORD](https://www.postgresql.org/docs/current/libpq-envars.html) or [PGPASSFILE](https://www.postgresql.org/docs/current/libpq-pgpass.html) environment variables to source login credentials.
The commands are mostly the same as the ones used for pgAdmin, except these are run directly from the command line and are expected to be run in the following format, replacing the relevant items in angle brackets accordingly:

```bash
psql.exe --dbname=<database name> --port=<PostgreSQL port provided during installation> --username=<user with access to database> --no-align --field-separator="" --tuples-only --command="<SQL queries>"
```

You may need to provide the full path to psql.exe, depending on how PostgreSQL was installed.

# Other game actions

Continue using the aforementioned advice above to determine how you should run the queries shown below.

## Adjust CPU player difficulty

As of writing this, the game provides two levels of difficulty for CPU controlled players.

To change the difficulty setting for a particular player, run the following command, replacing the relevant items in angle brackets accordingly:

```sql
UPDATE pong.players SET (cpuDifficultyLevel) = (SELECT <0 for base difficulty, 1 for increased difficulty>) WHERE playerNumber = <Player number to update>;
```

## Restart the game

You might want to reset the game to its original state. To do so, run the following command:

```sql
SELECT pong.resetGame();
```

You can also pass in up to two optional parameters to adjust the CPU difficulty for players 1 and 2 respectively.

# Uninstall

If using pgAdmin, you can right click on the "pong" schema and select "Drop Cascade".

If using psql.exe, use the same command format as shown previously but set following SQL query as the value for the command parameter:

```sql
DROP SCHEMA pong CASCADE;
```
