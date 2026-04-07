with Ada.Assertions;                use Ada.Assertions;
with Ada.Exceptions;                use Ada.Exceptions;
with Autopilot_System.Runtime.Control;
with Autopilot_System.Runtime.State;

package body Autopilot_System.IO.Driver_Input is

   procedure Log_Command_Exception
     (Context : in String;
      E       : in Exception_Occurrence) is
   begin
      Log ("DRIVER",
           Context & ": " & Exception_Name (E) & " " & Exception_Message (E));
   end Log_Command_Exception;

   procedure Handle_Engage is
      Current : constant System_State :=
        Autopilot_System.Runtime.State.Shared.Get_State;
   begin
      if Current = STANDBY then
         Autopilot_System.Runtime.State.Shared.Set_State (ENGAGING);
      else
         Log ("DRIVER",
              "Cannot ENGAGE - current state: " & System_State'Image (Current));
      end if;
   exception
      when E : Assertion_Error | Invalid_Transition =>
         Log_Command_Exception ("ENGAGE rejected", E);
      when E : others =>
         Log_Command_Exception ("ENGAGE failed", E);
   end Handle_Engage;

   procedure Handle_Disengage is
      Current : constant System_State :=
        Autopilot_System.Runtime.State.Shared.Get_State;
   begin
      if Current in ACTIVE | WARNING_ACTIVE then
         Autopilot_System.Runtime.State.Shared.Set_State (STANDBY);
      else
         Log ("DRIVER",
              "Cannot DISENGAGE from " & System_State'Image (Current));
      end if;
   exception
      when E : Assertion_Error | Invalid_Transition =>
         Log_Command_Exception ("DISENGAGE rejected", E);
      when E : others =>
         Log_Command_Exception ("DISENGAGE failed", E);
   end Handle_Disengage;

   procedure Handle_Override is
   begin
      Autopilot_System.Runtime.State.Shared.Set_State (STANDBY);
      Autopilot_System.Runtime.Control.Apply_Immediate_Output
        (Autopilot_System.Runtime.Control.IDLE_NOW);
      Log ("DRIVER", "OVERRIDE -> STANDBY");
   exception
      when E : Assertion_Error | Invalid_Transition =>
         Log_Command_Exception ("OVERRIDE rejected", E);
      when E : others =>
         Log_Command_Exception ("OVERRIDE failed", E);
   end Handle_Override;

   procedure Apply_Command (Cmd : in Driver_Command) is
   begin
      Log ("DRIVER", "Command received: " & Driver_Command'Image (Cmd));

      case Cmd is
         when ENGAGE =>
            Handle_Engage;
         when DISENGAGE =>
            Handle_Disengage;
         when OVERRIDE =>
            Handle_Override;
      end case;
   exception
      when E : Assertion_Error | Constraint_Error =>
         Log_Command_Exception ("Command contract failure", E);
      when E : others =>
         Log_Command_Exception ("Command runtime failure", E);
   end Apply_Command;

   task body Driver_Input_Task is
   begin
      accept Start;
      Log ("DRIVER", "Task started");

      loop
         select
            accept Send_Command (Cmd : in Driver_Command) do
               Apply_Command (Cmd);
            end Send_Command;
         or
            terminate;
         end select;
      end loop;
   end Driver_Input_Task;

end Autopilot_System.IO.Driver_Input;
