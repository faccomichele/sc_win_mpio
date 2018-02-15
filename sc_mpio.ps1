#Author: Michele Facco
#Date: 14-Feb-2018

# ************************************************************************************************************************************************************************
# *************************************************************************** APPEARANCE VARS ****************************************************************************
# ************************************************************************************************************************************************************************

$script:war_color = "yellow"  # Yellow Color - WARNINGS
$script:err_color = "red"     # Red Color - ERRORS
$script:ok_color = "green"    # Green Color - NOTIFICATIONS

# ************************************************************************************************************************************************************************
# ***************************************************************************** GLOBAL VARS ******************************************************************************
# ************************************************************************************************************************************************************************

$script:conf_file = "cfg.json" # Configuration File which is empty by default

$script:creds        # Credentials used to connect to a remote host
$script:sess         # Session created with a remote host
$script:fe_conn_type # Front-End connectivity type { (1) SAS - (2) FC - (3) iSCSI }
$script:lbp_type     # Load-Balancing Policy type { (RR) Round Robin - (LQB) Least Queue Depth }
$script:win_version  # Version of MS Windows OS
$script:auto_run     # Auto run the script with the settings found in the config file { (1) Enabled - (2) Disabled }
$script:chk_only     # Runs only checks, do not fix any settings even if it is wrong { (1) Enabled - (2) Disabled }

# ************************************************************************************************************************************************************************
# ****************************************************************************** SENTENCES *******************************************************************************
# ************************************************************************************************************************************************************************

$script:txt_curr_using = "`nYou are currently using"
$script:txt_as_fe = "as Front-End connectivity type."
$script:txt_keep_it = "Do you want to modify it?`n"
$script:txt_which_fe = "`nWhich is the Front-End connectivity type you are currently using?`n"
$script:txt_export = "`nDo you want to export the current configuration to an external json file?`n"
$script:txt_yes_no = "`n1) Yes`n2) No"
$script:txt_choose = "`n`nChoose"
$script:txt_def_no = "(DEFAULT = No)"
$script:txt_def_yes = "(DEFAULT = Yes)"
$script:txt_fe_types = "`n1) SAS`n2) FC`n3) iSCSI"
$script:txt_imp_file = "`nNOTE: External config file found and imported!"
$script:txt_auto_run = "`nIMPORTANT: Auto Exec set to Enabled! This script will be run automatically in x seconds in unattended mode.`nTo stop the script, press CRTL+C now.`nTo disable this settings: open the config file and change AutoExec value to 2 = DISABLED."
$script:txt_chk_only = "`nNOTE: Check Only options"
$script:txt_chk_en = "enabled - no settings will be modified"
$script:txt_chk_dis = "disabled - settings will be automatically changed by this script"
$script:txt_lbp = "`nNOTE: Load-Balancing Policy set to"
$script:txt_miss_fe = "`nERROR: Missing Front-End type information within the config file."
$script:txt_abort = "SCRIPT EXECUTION TERMINATED!"
$script:txt_gen_err = "`nERROR:"
$script:txt_not_comp = "is not compatible with this script!"

# ************************************************************************************************************************************************************************
# ********************************************************************************* MAIN *********************************************************************************
# ************************************************************************************************************************************************************************

FUNCTION Dell_Script_Main() {

    # (1) Check for an existing configuration file
    IF (Test-Path -Path $script:conf_file) {
      $cfg_imp_obj = Get-Content $script:conf_file | ConvertFrom-Json
      $script:fe_conn_type = $cfg_imp_obj.FrontEnd
      $script:lbp_type = $cfg_imp_obj.LBPolicy
      $script:auto_run = $cfg_imp_obj.AutoExec
      Write-Host $script:txt_imp_file -ForegroundColor $script:ok_color
    }

    # (2) Automatic script execution option. If this option is present in the config file, the script will apply all the settings in unattended mode.
    IF ($script:auto_run -eq 1){
      Write-Host $script:txt_auto_run -ForegroundColor $script:war_color
      IF ($script:chk_only -eq 2){
        Write-Host $script:txt_chk_only $script:txt_chk_dis -ForegroundColor $script:war_color
      } ELSE {
        Write-Host $script:txt_chk_only $script:txt_chk_en -ForegroundColor $script:ok_color
      }
      # --- exec auto script now! ---
    }

    # (3) Define which Front-End is in use
    IF (($script:fe_conn_type -le 3) -and ($script:fe_conn_type -ge 1)){
      SWITCH -wildcard ($script:fe_conn_type) {
          1 { $fe_type = "SAS"
            break }
          2 { $fe_type = "FC"
            break }
          3 { $fe_type = "iSCSI"
            break }
      }
      IF ($(Dell_Read_Input("$script:txt_curr_using $fe_type $script:txt_as_fe $script:txt_keep_it $script:txt_yes_no $script:txt_choose $script:txt_def_no")(1)(2)(2)) -eq 1){
        Dell_Read_FE
      }
    } ELSE {
      IF ($script:auto_run -eq 1){ # If autoscript enabled, but value not defined or wrong in config file: BLOCKING ERROR! EXIT FROM THIS SCRIPT!
        Write-Host $script:txt_miss_fe $script:txt_abort -ForegroundColor $script:err_color
      } ELSE {
        Dell_Read_FE
      }
    }

    # (4) Select Load-Balancing Policy depending on the current FE.
    IF ($script:lbp_type){
      Write-Host $script:txt_lbp $script:lbp_type -ForegroundColor $script:ok_color
    }
    SWITCH -wildcard ($script:fe_conn_type) {
        1 { # SAS
            IF -not ($script:lbp_type -like "LQD") {
              #do you want to fix this?
            }
            $script:lbp_type = "LQD"
            Write-Host ""
            break }
        2 { # FC
            IF -not ($script:lbp_type -like "RR") {
              #do you want to fix this?
            }
            $script:lbp_type = "RR"
            break }
        3 { # iSCSI
            IF -not ($script:lbp_type -like "RR") {
              #do you want to fix this?
            }
            $script:lbp_type = "RR"
            break }
    }

    # (5) Chance to export the above configurations to an external file
    IF ($(Dell_Read_Input("$script:txt_export $script:txt_yes_no $script:txt_choose $script:txt_def_yes")(1)(2)(1)) -eq 1){
      $cfg_exp_obj = New-Dell_SC_Cfg($script:fe_conn_type)($script:lbp_type)
      ConvertTo-Json -InputObject $cfg_exp_obj | Set-Content $script:conf_file
    }

    # (6) Define which version of MS Windows OS is in use on this system
    $win_ver_name = (Get-WmiObject -Class Win32_OperatingSystem | ForEach-Object -MemberName Caption)
    SWITCH -wildcard ($win_ver_name) {
        "Microsoft Windows Server 2016*" {
            $script:win_version = 4
            break }
        "Microsoft Windows Server 2012 R2*" {
            $script:win_version = 3
            break }
        "Microsoft Windows Server 2012*" {
            $script:win_version = 2
            break }
        "Microsoft Windows Server 2008 R2*" {
            $script:win_version = 1
            break }
        default { # If OS version note recognized: BLOCKING ERROR! EXIT FROM THIS SCRIPT!
          Write-Host $script:txt_gen_err $win_ver_name $script:txt_not_comp $script: -ForegroundColor $script:err_color
          Exit }
    }

}

# ************************************************************************************************************************************************************************
# *************************************************************************** CUSTOM VAR TYPES ***************************************************************************
# ************************************************************************************************************************************************************************

FUNCTION New-Dell_SC_Cfg() {
    param ($FrontEnd, $LBPolicy, $AutoExec)

    $dell_sc_cfg = new-object PSObject

    $dell_sc_cfg | add-member -type NoteProperty -Name FrontEnd -Value $FrontEnd
    $dell_sc_cfg | add-member -type NoteProperty -Name LBPolicy -Value $LBPolicy
    $dell_sc_cfg | add-member -type NoteProperty -Name AutoExec -Value $AutoExec

    RETURN $dell_sc_cfg
}

# ************************************************************************************************************************************************************************
# *************************************************************************** HELPING FUNCTIONS **************************************************************************
# ************************************************************************************************************************************************************************

FUNCTION Dell_Read_Input( [string] $question, [int] $min_val, [int] $max_val, [int] $default) {    # NOTE: "min_val" must be greater than zero!!!
    DO {
      $choice = [int] $(Read-Host $question)
      IF ($choice -eq 0) {
        $choice = $default
      }
    }WHILE (($choice -gt $max_val) -or ($choice -lt $min_val))
    RETURN $choice
}

# ************************************************************************************************************************************************************************
# **************************************************************************** INPUT FUNCTIONS ***************************************************************************
# ************************************************************************************************************************************************************************

FUNCTION Dell_Read_FE() {
  $script:fe_conn_type = $(Dell_Read_Input ("$script:txt_which_fe $script:txt_fe_types $script:txt_choose")(1)(3))
}











Dell_Script_Main
