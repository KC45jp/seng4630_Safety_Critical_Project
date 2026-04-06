--  Shared types, constants, and contract helpers for the ADAS.
--  Every other child package depends on this one.

with Ada.Real_Time;

package Autopilot_System.Types is

   --  -- State machine -------------------------------------------------
   type System_State is (
      STANDBY,
      ENGAGING,
      ACTIVE,
      FAULT_MINOR,
      FAULT_MAJOR,
      EMERGENCY,
      SAFE_STOP);

   --  -- Fault severity -----------------------------------------------
   type Fault_Level is (NONE, WARNING, CRITICAL, FATAL);

   --  -- Sensor data record -------------------------------------------
   type Sensor_Data is record
      Speed          : Float;
      Front_Distance : Float;
      Lane_Offset    : Float;
      Speed_Valid    : Boolean;
      Distance_Valid : Boolean;
      Lane_Valid     : Boolean;
   end record;

   --  -- Actuator output record ---------------------------------------
   type Actuator_Output is record
      Throttle : Float;
      Brake    : Float;
      Steering : Float;
   end record;

   --  -- Driver commands ----------------------------------------------
   type Driver_Command is (ENGAGE, DISENGAGE, OVERRIDE);

   --  -- Custom exception for invalid transitions ---------------------
   Invalid_Transition : exception;

   --  -- Safety thresholds --------------------------------------------
   MAX_SPEED         : constant Float    := 130.0;
   MIN_SAFE_DISTANCE : constant Float    := 10.0;
   MAX_LANE_OFFSET   : constant Float    := 0.5;
   SENSOR_TIMEOUT    : constant Duration := 0.5;

   --  -- Time helpers -------------------------------------------------
   subtype Sensor_Time is Ada.Real_Time.Time;

   --  -- Sensor helper contracts --------------------------------------
   function All_Sensors_Valid (Data : Sensor_Data) return Boolean is
     (Data.Speed_Valid and Data.Distance_Valid and Data.Lane_Valid);

   function Any_Sensor_Invalid (Data : Sensor_Data) return Boolean is
     (not All_Sensors_Valid (Data));

   function Failed_Sensor_Count (Data : Sensor_Data) return Natural is
     (Boolean'Pos (not Data.Speed_Valid) +
      Boolean'Pos (not Data.Distance_Valid) +
      Boolean'Pos (not Data.Lane_Valid));

   function Multiple_Sensors_Failed (Data : Sensor_Data) return Boolean is
     (Failed_Sensor_Count (Data) >= 2);

   function Sensor_Data_In_Range (Data : Sensor_Data) return Boolean is
     ((not Data.Speed_Valid or else Data.Speed >= 0.0)
      and (not Data.Distance_Valid or else Data.Front_Distance >= 0.0)
      and (not Data.Lane_Valid or else abs (Data.Lane_Offset) <= 5.0));

   --  -- Control targets ----------------------------------------------
   TARGET_SPEED     : constant Float := 100.0;
   SAFE_FOLLOW_DIST : constant Float := 30.0;

   --  -- Contract helper: valid state-machine transitions -------------
   function Is_Valid_Transition (From, To : System_State) return Boolean is
     (if To = STANDBY then True
      elsif From = SAFE_STOP then False
      elsif From = STANDBY then To = ENGAGING
      elsif From = ENGAGING then To in ACTIVE | FAULT_MAJOR | SAFE_STOP
      elsif From = ACTIVE then
         To in FAULT_MINOR | FAULT_MAJOR | EMERGENCY | SAFE_STOP
      elsif From = FAULT_MINOR then
         To in ACTIVE | FAULT_MAJOR | EMERGENCY | SAFE_STOP
      elsif From = FAULT_MAJOR then To in EMERGENCY | SAFE_STOP
      elsif From = EMERGENCY then To = SAFE_STOP
      else False);

end Autopilot_System.Types;
