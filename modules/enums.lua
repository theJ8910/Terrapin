--Protocol
ANNOUNCE             = 0  --A turtle is online and looking for a mainframe to connect to
HANDSHAKE            = 1  --Mainframe wants to control a turtle
ACCEPT               = 2  --Turtle accepts control
REJECT               = 3  --Turtle rejects control
OK                   = 4  --A requested operation completed without error (this doesn't necessarily mean it was successful)
ERR                  = 5  --A requested operation could not be completed because an error occurred

--Basic movement
MOVE_FORWARD         = 6   --Yields
MOVE_BACK            = 7   --Yields
MOVE_UP              = 8   --Yields
MOVE_DOWN            = 9   --Yields
TURN_LEFT            = 10  --Yields
TURN_RIGHT           = 11  --Yields

--Attacking entities
ATTACK               = 12  --Yields
ATTACK_UP            = 13  --Yields
ATTACK_DOWN          = 14  --Yields

--Mining and placing blocks
--(note: effect is highly dependent on the selected item; e.g. dig() with a hoe tills dirt, and place() with a bucket scoops up water/lava)
DIG                  = 15  --Yields
DIG_UP               = 16  --Yields
DIG_DOWN             = 17  --Yields
PLACE                = 18  --Yields
PLACE_UP             = 19  --Yields
PLACE_DOWN           = 20  --Yields

--Block detection, comparison, and inspection commands
DETECT               = 21  --Yields
DETECT_UP            = 22  --Yields
DETECT_DOWN          = 23  --Yields
COMPARE              = 24  --Yields
COMPARE_UP           = 25  --Yields
COMPARE_DOWN         = 26  --Yields
INSPECT              = 27  --Yields
INSPECT_UP           = 28  --Yields
INSPECT_DOWN         = 29  --Yields

--World Item interactions (note: suck/drop can interact with inventories)
DROP                 = 30  --Yields
DROP_UP              = 31  --Yields
DROP_DOWN            = 32  --Yields
SUCK                 = 33  --Yields
SUCK_UP              = 34  --Yields
SUCK_DOWN            = 35  --Yields

--Inventory manipulation
ITEM_SELECT          = 36  --Yields
ITEM_GET_SELECTED    = 37  --Doesn't yield
ITEM_COUNT           = 38  --Doesn't yield
ITEM_FREE            = 39  --Doesn't yield
ITEM_DETAILS         = 40  --Doesn't yield
ITEM_MOVE            = 41  --Yields

--Equipment
EQUIP_LEFT           = 42  --Yields
EQUIP_RIGHT          = 43  --Yields

--Peripherals
PER_ISPRESENT        = 44  --Doesn't yield
PER_TYPE             = 45  --Doesn't yield

--Fuel
REFUEL               = 46  --Yields
FUEL_LEVEL           = 47  --Doesn't yield
FUEL_LIMIT           = 48  --Doesn't yield

--File system
FS_WRITE             = 49
FS_READ              = 50
FS_MKDIR             = 51
FS_DELETE            = 52
FS_COPY              = 53
FS_MOVE              = 54
FS_LIST              = 55
FS_EXISTS            = 56
FS_IS_DIR            = 57

--Operating system
SHUTDOWN             = 58
REBOOT               = 59

--Remote Programs
PROGRAM_ADD          = 60
PROGRAM_REMOVE       = 61
PROGRAM_RUN          = 62

--Can only be done by a Crafty turtle
CRAFT                = 63   --Yields

--Related to OpenPeripheral sensors
OPENP_SONIC_SCAN     = 200  --Yields
OPENP_PLAYERS        = 201  --Yields
OPENP_MINECART_IDS   = 202  --Yields
OPENP_MOB_IDS        = 204  --Yields
OPENP_ENTITY_IDS     = 203  --Yields
OPENP_PLAYER_BY_NAME = 205  --Yields
OPENP_PLAYER_BY_UUID = 206  --Yields
OPENP_MINECART_DATA  = 206  --Yields
OPENP_MOB_DATA       = 207  --Yields
OPENP_ENTITY_DATA    = 208  --Yields