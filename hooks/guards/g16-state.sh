# shellcheck shell=bash
# G16 mode state: Claude cannot write kern's session state or schedule a prompt that switches it.

guard_g16() {
  local p sd
  sd=$(state_dir)
  case "$TOOL" in
    Write | Edit | NotebookEdit)
      p=$(ti_get file_path) || p=$(ti_get notebook_path) || p=""
      case "$p" in
        "$sd"/* | */plugins/data/kern*/sessions/*) vote deny G16 "kern session state is written only by kern hooks; ask the user to type /kern:mode or /kern:autopilot" ;;
      esac
      ;;
    Bash)
      p=$(ti_get command) || p=""
      case "$p" in
        *"$sd"* | *plugins/data/kern*sessions*) vote deny G16 "commands may not touch kern session state" ;;
      esac
      ;;
    CronCreate | ScheduleWakeup | RemoteTrigger | SendMessage | Skill)
      case "$TOOL_INPUT" in
        *kern:autopilot* | *kern:mode*) vote deny G16 "$TOOL may not carry /kern:autopilot or /kern:mode; only the user types them" ;;
      esac
      ;;
  esac
}
