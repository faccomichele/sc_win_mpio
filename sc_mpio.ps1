#Author: Michele Facco
#Date: 02-Mar-2018
#Project: https://github.com/faccomichele/sc_win_mpio.git

# Based on: http://en.community.dell.com/techcenter/extras/m/white_papers/20437917/download
#      and: http://en.community.dell.com/techcenter/extras/m/white_papers/20441042
# Published on: January 2018
#          and: April 2017

# ************************************************************************************************************************************************************************
# *************************************************************************** APPEARANCE VARS ****************************************************************************
# ************************************************************************************************************************************************************************

$script:war_color = "yellow"  # Yellow Color - WARNINGS
$script:err_color = "red"     # Red Color - ERRORS
$script:ok_color = "green"    # Green Color - NOTIFICATIONS

# ************************************************************************************************************************************************************************
# ***************************************************************************** GLOBAL VARS ******************************************************************************
# ************************************************************************************************************************************************************************

# Default Values to be set...
$script:conf_file = "cfg.json"                # Configuration File which is empty by default
$script:auto_run_delay = 10                   # Seconds of delay before running the script in unattended mode
$script:dc_custom_name = "DatacenterCustom"   # Customer profile name for DelayACK disabled profile
$script:iscsi_port = "3260"                   # iSCSI port number

$script:regpath_mpio = "HKLM:\SYSTEM\CurrentControlSet\Services\mpio\Parameters"                                                # Registry path for MPIO settings
$script:regpath_disk = "HKLM:\SYSTEM\CurrentControlSet\Services\disk"                                                           # Registry path for disks settings
$script:regpath_iscsi = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e97b-e325-11ce-bfc1-08002be10318}\0002\Parameters"   # Registry path for iSCSI settings - MS iSCSI Software Initiator
# DriverDesc = Microsoft iSCSI Initiator

# No defaults...
$script:creds           # Credentials used to connect to a remote host
$script:sess            # Session created with a remote host
$script:fe_conn_type    # Front-End connectivity type { SAS (1) - FC (2) - iSCSI (3) }
$script:lbp_type        # Load-Balancing Policy type { RR (Round Robin) - LQB (Least Queue Depth) }
$script:win_version     # Version of MS Windows OS
$script:auto_run        # Auto run the script with the settings found in the config file { True (1 - Enabled) - False (2 - Disabled) }
$script:chk_only        # Runs only checks, do not fix any settings even if it is wrong { True (1 - Enabled) - False (2 - Disabled) }

# ************************************************************************************************************************************************************************
# ****************************************************************************** SENTENCES *******************************************************************************
# ************************************************************************************************************************************************************************

$script:txt_curr_using = "`nYou are currently using"
$script:txt_has_bs = "has been selected"
$script:txt_as_fe = "as Front-End connectivity type."
$script:txt_as_lbp = "as Load-Balancing Policy."
$script:txt_keep_it = "Do you want to modify it?`n"
$script:txt_which_fe = "`nWhich is the Front-End connectivity type you are currently using?`n"
$script:txt_export = "`nDo you want to export the current configuration to an external json file?`n"
$script:txt_yes_no = "`n1) Yes`n2) No"
$script:txt_choose = "`n`nChoose"
$script:txt_def_no = "(DEFAULT = No)"
$script:txt_def_yes = "(DEFAULT = Yes)"
$script:txt_fe_types = "`n1) SAS`n2) FC`n3) iSCSI"
$script:txt_imp_file = "External config file found and imported!"
$script:txt_auto_run = "Auto Exec set to Enabled! This script will be run automatically in $script:auto_run_delay seconds in unattended mode.`nTo stop the script, press CRTL+C now.`nTo disable this settings: open the config file and change AutoExec value to 2 = DISABLED."
$script:txt_chk_only = "Check Only options is"
$script:txt_chk_en = "enabled - no settings will be modified"
$script:txt_chk_dis = "disabled - settings will be automatically changed by this script!`nTo disable this settings: open the config file and change CheckOnly value to 1 = ENABLED."
$script:txt_lbp = "Load-Balancing Policy set to"
$script:txt_miss_fe = "Missing Front-End type information within the config file."
$script:txt_abort = "SCRIPT EXECUTION TERMINATED!`n"
$script:txt_gen_err = "`nERROR:"
$script:txt_gen_ok = "`nNOTE:"
$script:txt_gen_war = "`nWARNING:"
$script:txt_not_comp = "is not compatible with this script!"
$script:txt_auto_on = "`nDo you want to enable AutoExec in this config file?`n"
$script:txt_check_off = "Do you want to enable CheckOnly in this config file?`n"
$script:txt_mpio = "`nMPIO:"
$script:txt_chk_inst_ok = "Installed             --->  OK"
$script:txt_chk_inst_err = "Not Installed        --->  ERROR"
$script:txt_install_it = "Not Installed! Do you want to proceed to install it, now?`n"
$script:txt_r_req = "This operation requires a reboot of this system."
$script:txt_scmsdsm = "`nSC <---> MS DSM:"
$script:txt_chk_assoc_ok = "Associated             --->  OK"
$script:txt_chk_assoc_err = "Not Associated        --->  ERROR"
$script:txt_associate_it = "Not Associated! Do you want to proceed to associated it, now?`n"
$script:txt_reg_check = "`nWindows Registry Check:"
$script:txt_reg_while = "while it should be set to"
$script:txt_reg_fix = "`nDo you want to fix this value, now?`n"
$script:txt_paws = "`nRFC 1323 Timestamps is"
$script:txt_chk_en_ok = "Enabled             --->  OK"
$script:txt_chk_dis_err = "Disabled            --->  ERROR"
$script:txt_chk_en_err = "Enabled             --->  ERROR"
$script:txt_chk_dis_ok = "Disabled            --->  OK"
$script:txt_enable_it = "Disabled! Do you want to enable it, now?`n"
$script:txt_disable_it = "Enabled! Do you want to disable it, now?`n"
$script:txt_ack = "`nTCP Delay ACK is"
$script:txt_cus_pro = "`nCustom Profile '$script:dc_custom_name' is"

# ************************************************************************************************************************************************************************
# ********************************************************************************* MAIN *********************************************************************************
# ************************************************************************************************************************************************************************

FUNCTION Dell_Script_Main() {

    # (1) Check for an existing configuration file
    IF (Test-Path -Path $script:conf_file) {
      $cfg_imp_obj = Get-Content $script:conf_file -Raw | ConvertFrom-Json
      $script:fe_conn_type = $cfg_imp_obj.FrontEnd
      $script:lbp_type = $cfg_imp_obj.LBPolicy
      $script:auto_run = $cfg_imp_obj.AutoExec
      $script:chk_only = $cfg_imp_obj.CheckOnly
      Write-Host $script:txt_gen_ok $script:txt_imp_file -ForegroundColor $script:ok_color
    }

    # (2) Automatic script execution option. If this option is present in the config file, the script will apply all the settings in unattended mode.
    IF ($script:auto_run){
      Write-Host $script:txt_gen_war $script:txt_auto_run -ForegroundColor $script:war_color
      IF (-not $script:chk_only){
        Write-Host $script:txt_gen_war $script:txt_chk_only $script:txt_chk_dis -ForegroundColor $script:war_color
      } ELSE {
        Write-Host $script:txt_gen_ok $script:txt_chk_only $script:txt_chk_en -ForegroundColor $script:ok_color
      }
      Start-Sleep -s $script:auto_run_delay
    }

    # (3) Define which Front-End is in use
    IF (($script:fe_conn_type -like "SAS") -or ($script:fe_conn_type -like "FC") -or ($script:fe_conn_type -like "iSCSI")){
      IF (-not $script:auto_run){
        IF ($(Dell_Read_Input("$script:txt_curr_using $fe_conn_type $script:txt_as_fe $script:txt_keep_it $script:txt_yes_no $script:txt_choose $script:txt_def_no")(1)(2)(2)) -eq 1){
          Dell_Read_FE
        }
      } ELSE {
        Write-Host $script:txt_gen_ok $fe_conn_type $script:txt_has_bs $script:txt_as_fe -ForegroundColor $script:ok_color
      }
    } ELSE {
      # If autorun is enabled, but value not defined or wrong in config file: BLOCKING ERROR! EXIT FROM THIS SCRIPT!
      IF ($script:auto_run){
        Write-Host $script:txt_gen_err $script:txt_miss_fe $script:txt_abort -ForegroundColor $script:err_color
      } ELSE {
        Dell_Read_FE
      }
    }

    # (4) Select / Verify Load-Balancing Policy depending on the current FE
    SWITCH ($script:fe_conn_type) {
        "SAS" {
            Dell_LBP_Verification("LQD")
            break }
        "FC" {
            Dell_LBP_Verification("RR")
            break }
        "iSCSI" {
            Dell_LBP_Verification("RR")
            break }
    }

    # (5) Chance to export the above configurations to an external file
    IF (-not $script:auto_run){
      IF ($(Dell_Read_Input("$script:txt_export $script:txt_yes_no $script:txt_choose $script:txt_def_yes")(1)(2)(1)) -eq 1){
        IF ($(Dell_Read_Input("$script:txt_auto_on $script:txt_yes_no $script:txt_choose $script:txt_def_no")(1)(2)(2)) -eq 1){
          $script:auto_run = $TRUE
        } ELSE {
          $script:auto_run = $FALSE
        }
        IF ($(Dell_Read_Input("$script:txt_check_off $script:txt_yes_no $script:txt_choose $script:txt_def_yes")(1)(2)(1)) -eq 1){
          $script:chk_only = $TRUE
        } ELSE {
          $script:chk_only = $FALSE
        }
        $cfg_exp_obj = New-Dell_SC_Cfg($script:fe_conn_type)($script:lbp_type)($script:auto_run)($script:chk_only)
        ConvertTo-Json -InputObject $cfg_exp_obj | Set-Content $script:conf_file
      }
    }

    # (6) Define which version of MS Windows OS is in use on this system
    $win_ver_name = (Get-WmiObject -Class Win32_OperatingSystem | ForEach-Object -MemberName Caption)
    SWITCH -wildcard ($win_ver_name) {
        "Microsoft Windows Server 2016*" {
            $script:win_version = "W2016"
            break }
        "Microsoft Windows Server 2012 R2*" {
            $script:win_version = "W2012R2"
            break }
        "Microsoft Windows Server 2012*" {
            $script:win_version = "W2012"
            break }
        "Microsoft Windows Server 2008 R2*" {
            $script:win_version = "W2008R2"
            break }
        default { # If OS version note recognized: BLOCKING ERROR! EXIT FROM THIS SCRIPT!
          Write-Host $script:txt_gen_err $win_ver_name $script:txt_not_comp $script:txt_abort -ForegroundColor $script:err_color
          EXIT }
    }

    # (7) Run checks (and fixes, if needed)
    Dell_Check_MPIO
    Dell_Check_SCMSDSM
    # Dell-LBP
    Dell_Check_HF
    Dell_Check_REG

    # (8) Run additonal checks for iSCSI only (and fixes, if needed)
    IF ($script:fe_conn_type -like "iSCSI") {
      # Dell_Check_PAWS # obsolete function for 2008r2 and 2012 only
      Dell_Check_DelayACK
    }
}

# ************************************************************************************************************************************************************************
# *************************************************************************** CUSTOM VAR TYPES ***************************************************************************
# ************************************************************************************************************************************************************************

FUNCTION New-Dell_SC_Cfg() {
    param ([string] $FrontEnd, [string] $LBPolicy, [boolean] $AutoExec, [boolean] $CheckOnly)

    $dell_sc_cfg = new-object PSObject

    $dell_sc_cfg | add-member -type NoteProperty -Name FrontEnd -Value $FrontEnd
    $dell_sc_cfg | add-member -type NoteProperty -Name LBPolicy -Value $LBPolicy
    $dell_sc_cfg | add-member -type NoteProperty -Name AutoExec -Value $AutoExec
    $dell_sc_cfg | add-member -type NoteProperty -Name CheckOnly -Value $CheckOnly

    RETURN $dell_sc_cfg
}

# ************************************************************************************************************************************************************************
# *************************************************************************** HELPING FUNCTIONS **************************************************************************
# ************************************************************************************************************************************************************************

# Reading user's inputs (numerical based Q&As)
FUNCTION Dell_Read_Input() {
    param ([string] $question, [int] $min_val, [int] $max_val, [int] $default)  # NOTE: "min_val" must be greater than zero!!!

    DO {
      $choice = [int] $(Read-Host $question)
      IF ($choice -eq 0) {
        $choice = $default
      }
    }WHILE (($choice -gt $max_val) -or ($choice -lt $min_val))

    RETURN $choice
}


# Check if the Load Balancing value read from the config file is the recommended value for that type of FE connection
FUNCTION Dell_LBP_Verification() {
    param ([string] $type)

    IF (($script:lbp_type -like "RR") -or ($script:lbp_type -like "LQD")) {
      IF (-not $script:auto_run){
        IF (-not $script:lbp_type -like $type) {
          IF ($(Dell_Read_Input("$script:txt_curr_using $lbp_type $script:txt_as_lbp $script:txt_keep_it $script:txt_yes_no $script:txt_choose $script:txt_def_yes")(1)(2)(1)) -eq 1){
            $script:lbp_type = $type
          }
        }
      }
    } ELSE {
      $script:lbp_type = $type
    }

    Write-Host $script:txt_gen_ok $script:txt_lbp $script:lbp_type -ForegroundColor $script:ok_color
}


# HotFix verification - check if it is installed, given a KB number
FUNCTION Dell_HF_Verification() {
    param([string] $kbn)
    TRY {
      Get-HotFiX -Id $kbn -ErrorAction Stop
      Write-Host "`n$kbn is $script:txt_chk_inst_ok" -ForegroundColor $script:ok_color
    } CATCH {
      Write-Host "`n$kbn is $script:txt_chk_inst_err" -ForegroundColor $script:war_color
    }
}


# Windows Registry Verification - check if the value at the specific path is set to the given value
FUNCTION Dell_REG_Verification() {
  param ([string]$path, [string]$name, [string]$value)
  $current_value = (Get-ItemProperty -Path "$path" -Name "$name" -ErrorAction Stop).($name)
  $current_type = $current_value.gettype().name
  IF (($current_value -like $value) -and (($current_type -like "Int32") -or ($current_type -like "UInt32"))){
    Write-Host "$script:txt_reg_check $name = $value" -ForegroundColor $script:ok_color
  } ELSE {
    IF($script:auto_run) {
      IF ($script:chk_only) {
        Write-Host "$script:txt_reg_check $name = $current_value $script:txt_reg_while $value" -ForegroundColor $script:war_color
      } ELSE {
        Dell_Fix_REG ($path)($name)($value)
      }
    } ELSE {
      IF ($(Dell_Read_Input("$script:txt_reg_check $name = $current_value $script:txt_reg_while $value $script:txt_reg_fix $script:txt_yes_no $script:txt_choose $script:txt_def_yes")(1)(2)(1)) -eq 1){
        Dell_Fix_REG ($path)($name)($value)
      } ELSE {
        Write-Host "$script:txt_reg_check $name = $current_value $script:txt_reg_while $value" -ForegroundColor $script:war_color
      }
    }
  }
}


# Check that DelayACK is set to 1 / disabled for the given profile
FUNCTION Dell_DelayACK_Value_Verification() {
    $current_value_ack = [int] $(Get-NetTcpSetting -SettingName $script:dc_custom_name).DelayedAckFrequency
    $current_value_paws = $(Get-NetTcpSetting -SettingName $script:dc_custom_name).Timestamps
    IF (($current_value -ne 1) -or ($current_value_paws -like "Disabled")){
      IF ($script:auto_run) {
        IF ($script:chk_only) {
          IF ($current_value -ne 1){
            IF ($current_value_paws -like "Disabled") {
              Write-Host $script:txt_ack $script:txt_chk_en_err $script:txt_paws $script:txt_chk_dis_err -ForegroundColor $script:war_color
            } ELSE {
              Write-Host $script:txt_ack $script:txt_chk_en_err -ForegroundColor $script:war_color
              Write-Host $script:txt_paws $script:txt_chk_en_ok -ForegroundColor $script:ok_color
            }
          } ELSE {
            Write-Host $script:txt_ack $script:txt_chk_dis_ok -ForegroundColor $script:ok_color
            Write-Host $script:txt_paws $script:txt_chk_dis_err -ForegroundColor $script:war_color
          }
        } ELSE {
          Dell_Fix_DelayACK_Value
        }
      } ELSE {
        $question = ""
        $report = ""
        IF ($current_value -ne 1){
          IF ($current_value_paws -like "Disabled") {
            $question = "$script:txt_ack $script:txt_disable_it $script:txt_paws $script:txt_enable_it"
            $report = "$script:txt_ack $script:txt_chk_en_err $script:txt_paws $script:txt_chk_dis_err"
          } ELSE {
            Write-Host $script:txt_paws $script:txt_chk_en_ok -ForegroundColor $script:ok_color
            $question = "$script:txt_ack $script:txt_disable_it"
            $report = "$script:txt_ack $script:txt_chk_en_err"
          }
        } ELSE {
          Write-Host $script:txt_ack $script:txt_chk_dis_ok -ForegroundColor $script:ok_color
          $question = "$script:txt_paws $script:txt_enable_it"
          $report = "$script:txt_paws $script:txt_chk_dis_err"
        }
        $question = "$question $script:txt_yes_no $script:txt_choose $script:txt_def_yes"
        IF ($(Dell_Read_Input($question)(1)(2)(1)) -eq 1){
          Dell_Fix_DelayACK_Value
        } ELSE {
          Write-Host $report -ForegroundColor $script:war_color
        }
      }
    } ELSE {
      Write-Host $script:txt_ack $script:txt_chk_dis_ok $script:txt_paws $script:txt_chk_en_ok -ForegroundColor $script:ok_color
    }
}


# Verify the given profile is associated to the iSCSI connections
FUNCTION Dell_DelayACK_Profile_Verification() {
    TRY {
      $current_profile = $(Get-NetTransportFilter -SettingName $script:dc_custom_name)
      Write-Host "$script:txt_cus_pro $script:txt_chk_en_ok `n $current_profile" -ForegroundColor $script:ok_color
    } CATCH {
    IF ($script:auto_run) {
      IF ($script:chk_only) {
        Write-Host $script:txt_cus_pro $script:txt_chk_dis_err -ForegroundColor $script:war_color
      } ELSE {
        Dell_Fix_DelayACK_Profile
      }
    } ELSE {
      IF ($(Dell_Read_Input("$script:txt_cus_pro $script:txt_enable_it $script:txt_yes_no $script:txt_choose $script:txt_def_yes")(1)(2)(1)) -eq 1){
        Dell_Fix_DelayACK_Profile
      } ELSE {
        Write-Host $script:txt_cus_pro $script:txt_chk_dis_err -ForegroundColor $script:war_color
      }
    }
  }
}

# ************************************************************************************************************************************************************************
# **************************************************************************** INPUT FUNCTIONS ***************************************************************************
# ************************************************************************************************************************************************************************

# Ask users to input the specific FE type in use for this environment
FUNCTION Dell_Read_FE() {
    $fe_type = $(Dell_Read_Input ("$script:txt_which_fe $script:txt_fe_types $script:txt_choose")(1)(3))
    SWITCH ($fe_type) {
        1 {
            $script:fe_conn_type = "SAS"
            break }
        2 {
            $script:fe_conn_type = "FC"
            break }
        3 {
            $script:fe_conn_type = "iSCSI"
            break }
    }
}

# ************************************************************************************************************************************************************************
# **************************************************************************** CHECK FUNCTIONS ***************************************************************************
# ************************************************************************************************************************************************************************

# Verify that MPIO is Installed
FUNCTION Dell_Check_MPIO() {
    IF ((Get-WindowsOptionalFeature -Online -FeatureName MultipathIO).State -like "Disabled") {
      IF ($script:auto_run) {
        IF ($script:chk_only) {
          Write-Host $script:txt_mpio $script:txt_chk_inst_err -ForegroundColor $script:err_color
        } ELSE {
          Dell_Fix_MPIO
        }
      } ELSE {
        IF ($(Dell_Read_Input("$script:txt_mpio $script:txt_install_it $script:txt_yes_no $script:txt_gen_war $script:txt_r_req $script:txt_choose $script:txt_def_yes")(1)(2)(1)) -eq 1){
          Dell_Fix_MPIO
        } ELSE { # If MPIO is not installed, script cannot continue: BLOCKING ERROR! EXIT FROM THIS SCRIPT!
          Write-Host $script:txt_mpio $script:txt_chk_inst_err -ForegroundColor $script:err_color
          Write-Host $script:txt_abort -ForegroundColor $script:err_color
          EXIT
        }
      }
    } ELSE {
        Write-Host $script:txt_mpio $script:txt_chk_inst_ok -ForegroundColor $script:ok_color
    }
}


# Check Microsoft Device-Specific Module if it contains the corrent entry for SC Series devices
FUNCTION Dell_Check_SCMSDSM() {
    TRY {
      $null = $(Get-MSDSMSupportedHW -VendorId COMPELNT -ProductID "Compellent Vol" -ErrorAction Stop)
      Write-Host $script:txt_scmsdsm $script:txt_chk_assoc_ok -ForegroundColor $script:ok_color
    } CATCH {
      IF($script:auto_run) {
        IF ($script:chk_only) {
          Write-Host $script:txt_scmsdsm $script:txt_chk_assoc_err -ForegroundColor $script:war_color
        } ELSE {
          Dell_Fix_SCMSDSM
        }
      } ELSE {
        IF ($(Dell_Read_Input("$script:txt_scmsdsm $script:txt_associate_it $script:txt_yes_no $script:txt_choose $script:txt_def_yes")(1)(2)(1)) -eq 1){
          Dell_Fix_SCMSDSM
        } ELSE {
          Write-Host $script:txt_scmsdsm $script:txt_chk_assoc_err -ForegroundColor $script:war_color
        }
      }
    }
}


# List of Hot Fixes to check based on the Windows version in use
FUNCTION Dell_Check_HF() {
    SWITCH -wildcard ($script:win_version) {
        "W2016" {
            Dell_HF_Verification("KB4056890") # http://support.microsoft.com/kb/4056890
            break }
        "W2012R2" {
            Dell_HF_Verification("KB4054519") # http://support.microsoft.com/kb/4054519
            break }
        "W2012" {
            IF ($script:fe_conn_type -like "iSCSI") {
              Dell_HF_Verification("KB3102997") # http://support.microsoft.com/kb/3102997
            }
            IF ($script:fe_conn_type -like "SAS") {
              Dell_HF_Verification("KB3018489") # http://support.microsoft.com/kb/3018489
            }
            Dell_HF_Verification("KB3046101") # http://support.microsoft.com/kb/3046101
            break }
        "W2008R2" {
            Dell_HF_Verification("KB3125574") # http://support.microsoft.com/kb/3125574
            break }
    }
}


# List of params to check (as well as their path and Best Practices values)
# WARNING: hybrid PS / SC Series environment is out of the scope of this script for now, but it will implemented within the next releases.
FUNCTION Dell_Check_REG() {
    Dell_REG_Verification($script:regpath_mpio)("PDORemovePeriod")("120")                   # Default = 20 | Shared EQL/CML = 120 (Required)
    Dell_REG_Verification($script:regpath_mpio)("PathRecoveryInterval")("25")               # Default = 40 | Shared EQL/CML = 60 (Required)
    Dell_REG_Verification($script:regpath_mpio)("UseCustomPathRecoveryInterval")("1")       # Default = 0 | Shared EQL/CML = 1 (Required)
    Dell_REG_Verification($script:regpath_mpio)("PathVerifyEnabled")("1")                   # Default = 0 | Shared EQL/CML = 1 (Required)
    Dell_REG_Verification($script:regpath_mpio)("PathVerificationPeriod")("30")             # no change - Default = 30 | Shared EQL/CML = 30 (Required)
    Dell_REG_Verification($script:regpath_mpio)("RetryInterval")("1")                       # no change - Default = 1 | Shared EQL/CML = 1 (Required)

    IF ($script:fe_conn_type -like "SAS") {
		  Dell_REG_Verification($script:regpath_mpio)("RetryCount")("15")                       # Default = 3
	  } ELSE {
		  Dell_REG_Verification($script:regpath_mpio)("RetryCount")("3")                        # no change - Default = 3 | Shared EQL/CML = 3 (Required)
	  }

    SWITCH -wildcard ($script:win_version) {
        "W201*" {
            Dell_REG_Verification($script:regpath_mpio)("DiskPathCheckDisabled")("0")      # no change - Default = 0
            Dell_REG_Verification($script:regpath_mpio)("DiskPathCheckInterval")("25")     # Default = 10
            Dell_REG_Verification($script:regpath_disk)("TimeoutValue")("60")              # no change - Default = 60 | Shared EQL/CML = 60 (Required)
            break }
        "W2008*" {
            Dell_REG_Verification($script:regpath_mpio)("DiskPathCheckEnabled")("1")       # Default - does not exist
            Dell_REG_Verification($script:regpath_mpio)("DiskPathCheckInterval")("25")     # Default - does not exist
            break }
    }

    IF ($script:fe_conn_type -like "iSCSI") {
      Dell_REG_Verification($script:regpath_iscsi)("MaxRequestHoldTime")("90")             # Default = 60 | Shared EQL/CML = 90 (Required)
      Dell_REG_Verification($script:regpath_iscsi)("LinkDownTime")("35")                   # Default = 15 | Shared EQL/CML = 35 (Required)
      Dell_REG_Verification($script:regpath_iscsi)("TCPConnectTime")("15")                 # no change - Default = 15 | Shared EQL/CML = 15 (Required)
      Dell_REG_Verification($script:regpath_iscsi)("TCPDisconnectTime")("15")              # no change - Default = 15 | Shared EQL/CML = 15 (Required)
      Dell_REG_Verification($script:regpath_iscsi)("WMIRequestTimeout")("30")              # no change - Default = 30 | Shared EQL/CML = 30 (Required)
      Dell_REG_Verification($script:regpath_iscsi)("DelayBetweenReconnect")("5")           # no change - Default = 5 | Shared EQL/CML = 1 (Required)
      Dell_REG_Verification($script:regpath_iscsi)("MaxConnectionRetries")("4294967295")   # no change - Default = 4294967295
      Dell_REG_Verification($script:regpath_iscsi)("MaxPendingRequests")("255")            # no change - Default = 255 | Shared EQL/CML = 255 (Required)
      Dell_REG_Verification($script:regpath_iscsi)("EnableNOPOut")("1")                    # Default = 0 | Shared EQL/CML = 1 (Required)
      Dell_REG_Verification($script:regpath_iscsi)("MaxTransferLength")("262144")          # no change - Default = 262144
      Dell_REG_Verification($script:regpath_iscsi)("MaxBurstLength")("262144")             # no change - Default = 262144
      Dell_REG_Verification($script:regpath_iscsi)("FirstBurstLength")("65536")            # no change - Default = 65536
      Dell_REG_Verification($script:regpath_iscsi)("MaxRecvDataSegmentLength")("65536")    # no change - Default = 65536
      Dell_REG_Verification($script:regpath_iscsi)("IPSecConfigTimeout")("60")             # no change - Default = 60
      Dell_REG_Verification($script:regpath_iscsi)("InitialR2T")("0")                      # no change - Default = 0
      Dell_REG_Verification($script:regpath_iscsi)("ImmediateData")("1")                   # no change - Default = 1
      Dell_REG_Verification($script:regpath_iscsi)("PortalRetryCount")("5")                # no change - Default = 5 | Shared EQL/CML = 1 (Required)
      Dell_REG_Verification($script:regpath_iscsi)("NetworkReadyRetryCount")("10")         # no change - Default = 10 | Shared EQL/CML = 10 (Required)
      Dell_REG_Verification($script:regpath_iscsi)("ErrorRecoveryLevel")("2")              # no change - Default = 2 | Shared EQL/CML = 2 (Required)
      # --- ADDITIONAL NOTES FOR SHARED ENVIRONMENT --- (checks for shared env not implemented yet)
      # + AsyncLogout PauseTimeout = 10 | Shared EQL/CML = 10 (Required)
      # HKEY_LOCAL_MACHINE\SYSTEM\ CurrentControlSet\Services\Tcpip\Parameters\Interfaces\<Interface GUID>\TCPAckFrequency = 1 (recommended in shared env)
      # HKEY_LOCAL_MACHINE\SYSTEM\ CurrentControlSet\Services\Tcpip\Parameters\Interfaces\<SAN interface GUID>\TcpNoDelay = 1 (required in shared env)
      # WindowSize Scaling = 3 (time stamp + window scaling enabled) - (required in shared env)
    }
}


# Verify that RFC timestamps settings has been enabled on this system, obsolete check
FUNCTION Dell_Check_PAWS() {
    IF ($(netsh int tcp show global store=persistent | find "RFC 1323 Timestamps").substring(38) -like "disabled") {
      IF($script:auto_run) {
        IF ($script:chk_only) {
          Write-Host $script:txt_paws $script:txt_chk_dis_err -ForegroundColor $script:war_color
        } ELSE {
          Dell_Fix_PAWS
        }
      } ELSE {
        IF ($(Dell_Read_Input("$script:txt_paws $script:txt_enable_it $script:txt_yes_no $script:txt_choose $script:txt_def_yes")(1)(2)(1)) -eq 1){
          Dell_Fix_PAWS
        } ELSE {
          Write-Host $script:txt_paws $script:txt_chk_dis_err -ForegroundColor $script:war_color
        }
      }
    } ELSE {
      Write-Host $script:txt_paws $script:txt_chk_en_ok -ForegroundColor $script:ok_color
    }
}


# Verify that DelayACK is set to false (frequency = 1) and that this specific profile is ENABLED, Also check PAWS on the new system
FUNCTION Dell_Check_DelayACK() {
    Dell_DelayACK_Value_Verification
    Dell_DelayACK_Profile_Verification
}

# ************************************************************************************************************************************************************************
# **************************************************************************** FIXES FUNCTIONS ***************************************************************************
# ************************************************************************************************************************************************************************

#Enable MPIO if not enabled (REBOOT IS REQUIRED)
FUNCTION Dell_Fix_MPIO() {
    Enable-WindowsOptionalFeature -Online -FeatureName MultiPathIO
}


# Create an entry for SC Series model in the MS Device-Specific Module (reboot required to have it applied)
FUNCTION Dell_Fix_SCMSDSM() {
    New-MSDSMSupportedHW -VendorId COMPELNT -ProductID "Compellent Vol"
    Update-MPIOClaimedHW -Confirm:$false
    Dell_Check_SCMSDSM
}


# Fix a specific Windows Registy value for a entry of a given name in a given path
FUNCTION Dell_Fix_REG() {
    param ([string]$path, [string]$name, [string]$value)

    Set-ItemProperty -Path $path -Name $name -Value $value -Type DWord # -ErrorAction SilentlyContinue
    Dell_REG_Verification($path)($name)($value)
}


# Enable RFC timestamps settings if not enabled
FUNCTION Dell_Fix_PAWS() {
    netsh int tcp set global timestamps=enabled
    Dell_Check_PAWS
}


# Set DelayACK to 1 / disabled for the given profile
FUNCTION Dell_Fix_DelayACK_Value() {
    Set-NetTcpSetting -SettingName $script:dc_custom_name -DelayedAckFrequency 1
    Set-NetTcpSetting -SettingName $script:dc_custom_name -Timestamps Enabled
    Dell_DelayACK_Value_Verification
}


# Associate the given profile name to the iSCSI connections
FUNCTION Dell_Fix_DelayACK_Profile() {
    New-NetTransportFilter -SettingName $script:dc_custom_name -LocalPortStart 0 -LocalPortEnd 65535 -RemotePortStart $script:iscsi_port -RemotePortEnd $script:iscsi_port
    Dell_DelayACK_Profile_Verification
}















# page 33 is missing and must be implemented
# Note: A reboot is required for any registry changes to take effect. Alternatively, unloading and reloading the initiator driver will also cause the change to take effect. In the Device Manager GUI, look under Storage controllers, right-click Microsoft iSCSI Initiator, and select Disable to unload the driver. Then select Enable to reload the driver.
#Disable NIC Interrupt Modulation:
#1. Click Adapter Settings.
#2. Right-click the adapter and select Properties.
#3. Under the Networking tab, click Configure.
#4. Under the Advanced tab, select Interrupt Moderation and choose Disabled.

#HKEY LOCAL_MACHINE \ SYSTEM \ CurrentControlSet \ Services \ Tcpip \ Parameters \ Interfaces \ <SAN interface GUID>
# Entries:
#TcpAckFrequency
#TcpNoDelay
# Value type:
#REG_DWORD, number
# Value to disable:
#1

# Load Balancing Policy
# Dell Storage Center OS (SCOS) 6.5 and earlier: round robin (default) and failover only
# SCOS 6.6 and later: round robin (default), failover only, and least queue depth
# SAS FE: round robin with subset (default), least queue depth, and weighted paths
# mpclaim.exe -L -M <0-7> -d "COMPELNTCompellent Vol"
# 2 = Round Robin / 3 = Round Robin with Subset / 4 = Least Queue Depth
# MPCLAIM can be used also for per-volume basis

#For a shared PS Series and SC Series Windows host, it is recommended that Jumbo frames and flow control be enabled for both the Broadcom 57810 and the Intel® X520. If not using the Broadcom iSCSI Offload Engine, receive and transmit buffers should also be maximized.
















Dell_Script_Main
