with Autopilot_System.Domain.Types; use Autopilot_System.Domain.Types;

package Autopilot_System.IO.Driver_Input is

   --  Driver command task using Ada rendezvous.
   --  External callers issue commands via the Send_Command entry;
   --  scenario playback may reuse the same command logic directly.

   procedure Apply_Command (Cmd : in Driver_Command);

   task type Driver_Input_Task is
      entry Send_Command (Cmd : in Driver_Command);
      entry Start;
   end Driver_Input_Task;

end Autopilot_System.IO.Driver_Input;
