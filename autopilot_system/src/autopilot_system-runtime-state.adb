with Ada.Real_Time; use Ada.Real_Time;

package body Autopilot_System.Runtime.State is

   protected body Shared is

      -- getters!
      function Get_Sensors return Sensor_Data is
      begin
         return Current_Sensors;
      end Get_Sensors;

      function Get_State return System_State is
      begin
         return Current_State;
      end Get_State;

      function Get_Fault return Fault_Level is
      begin
         return Current_Fault;
      end Get_Fault;

      function Get_Actuators return Actuator_Output is
      begin
         return Current_Actuators;
      end Get_Actuators;

      function Get_Last_Speed_Update return Sensor_Time is
      begin
         return Last_Speed_Update;
      end Get_Last_Speed_Update;

      function Get_Last_Distance_Update return Sensor_Time is
      begin
         return Last_Distance_Update;
      end Get_Last_Distance_Update;

      function Get_Last_Lane_Update return Sensor_Time is
      begin
         return Last_Lane_Update;
      end Get_Last_Lane_Update;

      -- setters!
      procedure Update_Sensors (Data : in Sensor_Data) is
         Now : constant Time := Clock;
      begin
         Current_Sensors := Data;
         Last_Speed_Update    := Now;
         Last_Distance_Update := Now;
         Last_Lane_Update     := Now;
      end Update_Sensors;

      procedure Update_Speed (Value : in Float; Valid : in Boolean) is
      begin
         Current_Sensors.Speed       := Value;
         Current_Sensors.Speed_Valid := Valid;
         Last_Speed_Update           := Clock;
      end Update_Speed;

      procedure Update_Distance (Value : in Float; Valid : in Boolean) is
      begin
         Current_Sensors.Front_Distance := Value;
         Current_Sensors.Distance_Valid := Valid;
         Last_Distance_Update           := Clock;
      end Update_Distance;

      procedure Update_Lane (Value : in Float; Valid : in Boolean) is
      begin
         Current_Sensors.Lane_Offset := Value;
         Current_Sensors.Lane_Valid  := Valid;
         Last_Lane_Update            := Clock;
      end Update_Lane;

      procedure Set_State (S : in System_State) is
      begin
         if not Is_Valid_Transition (Current_State, S) then
            raise Invalid_Transition with
              System_State'Image (Current_State) & " -> " &
              System_State'Image (S);
         end if;

         Current_State := S;
      end Set_State;

      procedure Set_Fault (F : in Fault_Level) is
      begin
         Current_Fault := F;
      end Set_Fault;

      procedure Set_Actuators (A : in Actuator_Output) is
      begin
         Current_Actuators := A;
      end Set_Actuators;

   end Shared;

end Autopilot_System.Runtime.State;
