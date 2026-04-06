with Ada.Assertions;                use Ada.Assertions;
with Ada.Exceptions;                use Ada.Exceptions;
with Ada.Numerics.Float_Random;
with Autopilot_System.Types;        use Autopilot_System.Types;
with Autopilot_System.Vehicle_State;

package body Autopilot_System.Sensors is

   function Random_Flag
     (Gen : in out Ada.Numerics.Float_Random.Generator;
      Threshold : Float) return Boolean is
     (Ada.Numerics.Float_Random.Random (Gen) > Threshold);

   function Empty_Frame return Sensor_Data is
     (Speed          => 0.0,
      Front_Distance => 0.0,
      Lane_Offset    => 0.0,
      Speed_Valid    => False,
      Distance_Valid => False,
      Lane_Valid     => False);

   procedure Generate_Normal_Phase
     (Gen  : in out Ada.Numerics.Float_Random.Generator;
      Data : out Sensor_Data) is
   begin
      Data.Speed          := 80.0 + Ada.Numerics.Float_Random.Random (Gen) * 30.0;
      Data.Front_Distance := 40.0 + Ada.Numerics.Float_Random.Random (Gen) * 60.0;
      Data.Lane_Offset    := (Ada.Numerics.Float_Random.Random (Gen) - 0.5) * 0.3;
      Data.Speed_Valid    := True;
      Data.Distance_Valid := True;
      Data.Lane_Valid     := True;
   end Generate_Normal_Phase;

   procedure Generate_Warning_Phase
     (Gen  : in out Ada.Numerics.Float_Random.Generator;
      Data : out Sensor_Data) is
   begin
      Data.Speed          := 115.0 + Ada.Numerics.Float_Random.Random (Gen) * 25.0;
      Data.Front_Distance := 8.0 + Ada.Numerics.Float_Random.Random (Gen) * 25.0;
      Data.Lane_Offset    := (Ada.Numerics.Float_Random.Random (Gen) - 0.5) * 1.2;
      Data.Speed_Valid    := Random_Flag (Gen, 0.05);
      Data.Distance_Valid := Random_Flag (Gen, 0.10);
      Data.Lane_Valid     := Random_Flag (Gen, 0.10);
   end Generate_Warning_Phase;

   procedure Generate_Critical_Phase
     (Gen  : in out Ada.Numerics.Float_Random.Generator;
      Data : out Sensor_Data) is
   begin
      Data.Speed          := 50.0 + Ada.Numerics.Float_Random.Random (Gen) * 90.0;
      Data.Front_Distance := Ada.Numerics.Float_Random.Random (Gen) * 12.0;
      Data.Lane_Offset    := (Ada.Numerics.Float_Random.Random (Gen) - 0.5) * 2.0;
      Data.Speed_Valid    := Random_Flag (Gen, 0.35);
      Data.Distance_Valid := Random_Flag (Gen, 0.45);
      Data.Lane_Valid     := Random_Flag (Gen, 0.45);
   end Generate_Critical_Phase;

   procedure Populate_Frame
     (Gen  : in out Ada.Numerics.Float_Random.Generator;
      Step : in Natural;
      Data : out Sensor_Data) is
   begin
      if Step <= 60 then
         Generate_Normal_Phase (Gen, Data);
      elsif Step <= 100 then
         Generate_Warning_Phase (Gen, Data);
      else
         Generate_Critical_Phase (Gen, Data);
      end if;
   end Populate_Frame;

   procedure Apply_Emergency_Profile
     (State           : in System_State;
      Emergency_Steps : in out Natural;
      Data            : in out Sensor_Data) is
   begin
      if State in EMERGENCY | SAFE_STOP then
         Emergency_Steps := Emergency_Steps + 1;
         Data.Speed          := Float'Max (0.0, 80.0 - Float (Emergency_Steps) * 8.0);
         Data.Front_Distance := 3.0;
         Data.Lane_Offset    := 0.0;
         Data.Speed_Valid    := True;
         Data.Distance_Valid := True;
         Data.Lane_Valid     := True;
      else
         Emergency_Steps := 0;
      end if;
   end Apply_Emergency_Profile;

   procedure Publish_Frame (Data : in Sensor_Data) is
   begin
      Autopilot_System.Vehicle_State.Shared.Update_Sensors (Data);
   exception
      when E : Assertion_Error | Constraint_Error =>
         Log ("SENSOR",
              "Sensor frame rejected: " & Exception_Name (E) &
              " " & Exception_Message (E));
      when E : others =>
         Log ("SENSOR",
              "Unexpected publish error: " & Exception_Name (E) &
              " " & Exception_Message (E));
   end Publish_Frame;

   procedure Log_Sensor_Snapshot (Step : in Natural; Data : in Sensor_Data) is
   begin
      if Step mod 20 /= 0 then
         return;
      end if;

      if All_Sensors_Valid (Data) then
         Log ("SENSOR",
              "Step" & Natural'Image (Step) &
              " Spd=" & Float'Image (Data.Speed) &
              " Dist=" & Float'Image (Data.Front_Distance) &
              " Lane=" & Float'Image (Data.Lane_Offset));
      else
         Log ("SENSOR",
              "Step" & Natural'Image (Step) &
              " Validity S=" & Boolean'Image (Data.Speed_Valid) &
              " D=" & Boolean'Image (Data.Distance_Valid) &
              " L=" & Boolean'Image (Data.Lane_Valid));
      end if;
   end Log_Sensor_Snapshot;

   procedure Log_Cycle_Exception
     (Context : in String;
      E       : in Exception_Occurrence) is
   begin
      Log ("SENSOR",
           Context & ": " & Exception_Name (E) & " " & Exception_Message (E));
   end Log_Cycle_Exception;

   task body Sensor_Task is
      Gen             : Ada.Numerics.Float_Random.Generator;
      Data            : Sensor_Data := Empty_Frame;
      Step            : Natural := 0;
      Emergency_Steps : Natural := 0;
   begin
      Ada.Numerics.Float_Random.Reset (Gen);

      accept Start;
      Log ("SENSOR", "Task started");

      loop
         select
            accept Stop;
            Log ("SENSOR", "Task stopping");
            exit;
         or
            delay 0.05;
         end select;

         begin
            Step := Step + 1;
            Populate_Frame (Gen, Step, Data);
            Apply_Emergency_Profile
              (Autopilot_System.Vehicle_State.Shared.Get_State,
               Emergency_Steps,
               Data);
            Publish_Frame (Data);
            Log_Sensor_Snapshot (Step, Data);
         exception
            when E : Assertion_Error | Constraint_Error =>
               Log_Cycle_Exception ("Cycle contract failure", E);
               Publish_Frame (Empty_Frame);
            when E : others =>
               Log_Cycle_Exception ("Cycle runtime failure", E);
               Publish_Frame (Empty_Frame);
         end;
      end loop;
   end Sensor_Task;

end Autopilot_System.Sensors;
