with Autopilot_System.Types; use Autopilot_System.Types;

package Autopilot_System.Driver_Input is

   --  Driver command task using Ada rendezvous.
   --  External callers issue commands via the Send_Command entry;
   --  the task applies them to Vehicle_State.

   task type Driver_Input_Task is
      entry Send_Command (Cmd : in Driver_Command);
      entry Start;
   end Driver_Input_Task;

end Autopilot_System.Driver_Input;
