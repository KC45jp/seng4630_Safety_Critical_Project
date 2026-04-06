with Ada.Real_Time;
with Autopilot_System.Types; use Autopilot_System.Types;

package Autopilot_System.Vehicle_State is

   protected Shared is

      function Get_Sensors return Sensor_Data;
      function Get_State return System_State;
      function Get_Fault return Fault_Level;
      function Get_Actuators return Actuator_Output;
      function Get_Last_Speed_Update return Sensor_Time;
      function Get_Last_Distance_Update return Sensor_Time;
      function Get_Last_Lane_Update return Sensor_Time;

      procedure Update_Sensors (Data : in Sensor_Data)
        with Pre => Sensor_Data_In_Range (Data);

      procedure Set_State (S : in System_State);

      procedure Set_Fault (F : in Fault_Level);

      procedure Set_Actuators (A : in Actuator_Output)
        with Pre => A.Throttle >= 0.0 and A.Throttle <= 1.0
                    and A.Brake >= 0.0 and A.Brake <= 1.0
                    and A.Steering >= -1.0 and A.Steering <= 1.0;

   private
      Current_Sensors : Sensor_Data :=
        (Speed          => 0.0,
         Front_Distance => 100.0,
         Lane_Offset    => 0.0,
         Speed_Valid    => True,
         Distance_Valid => True,
         Lane_Valid     => True);
      Current_State : System_State := STANDBY;
      Current_Fault : Fault_Level := NONE;
      Current_Actuators : Actuator_Output :=
        (Throttle => 0.0,
         Brake    => 0.0,
         Steering => 0.0);
      Last_Speed_Update : Sensor_Time := Ada.Real_Time.Clock;
      Last_Distance_Update : Sensor_Time := Ada.Real_Time.Clock;
      Last_Lane_Update : Sensor_Time := Ada.Real_Time.Clock;
   end Shared;

end Autopilot_System.Vehicle_State;
