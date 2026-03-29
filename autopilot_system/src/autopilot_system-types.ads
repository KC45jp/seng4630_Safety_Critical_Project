package Autopilot_System.Types is
   -- State machine nodes
   type System_State is (
      STANDBY,      -- Waiting (autopilot off)
      ENGAGING,     -- Safety check in progress before activation
      ACTIVE,       -- Autopilot running normally
      FAULT_MINOR,  -- Minor fault (warning only, driving continues)
      FAULT_MAJOR,  -- Major fault (degraded control)
      EMERGENCY,    -- Emergency braking in progress
      SAFE_STOP     -- Vehicle stopped safely (terminal state)
   );

   -- Fault severity levels
   type Fault_Level is (NONE, WARNING, CRITICAL, FATAL);

   type Speed_Sensor is record
      Speed : Float; -- km/h
      FLevel : Fault_Level;
   end record;

   type Front_Distance_Sensor is record
      Front_Distance: Float;-- m (distance to front obstacle)
      FLevel : Fault_Level;
   end record;

   type Lane_Offset_Sensor is record
      Lane_Offset    : Float; -- m (lateral offset from lane centre) right side is positive, leftside is negative
      FLevel : Fault_Level;
   end record;

   -- Sensor data record
   type Sensor_Data is record
      Speed          : Speed_Sensor;   
      Front_Distance : Front_Distance_Sensor;   
      Lane_Offset    : Lane_Offset_Sensor;   
   end record;

   -- Actuator output record
   type Actuator_Output is record
      Throttle : Float;   -- 0.0 to 1.0
      Brake    : Float;   -- 0.0 to 1.0
      Steering : Float;   -- -1.0 (full left) to 1.0 (full right)
   end record;

   -- Driver commands
   type Driver_Command is (ENGAGE, DISENGAGE, OVERRIDE);

   -- Safety constants
   MAX_SPEED         : constant Float    := 130.0;  -- km/h
   MIN_SAFE_DISTANCE : constant Float    := 10.0;   -- m
   MAX_LANE_OFFSET   : constant Float    := 0.5;    -- m
   SENSOR_TIMEOUT    : constant Duration := 0.5;    -- seconds

end Autopilot_System.Types;
