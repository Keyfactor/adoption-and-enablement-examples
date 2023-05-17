$keyfactorUser = "{{keyfactorUser}}"
$keyfactorPassword = "{{keyfactorPassword}}"
$secKeyfactorPassword = ConvertTo-SecureString $keyfactorPassword -AsPlainText -Force
$credKeyfactor = New-Object System.Management.Automation.PSCredential ($keyfactorUser, $secKeyfactorPassword)
Set-Location "{{ install_source_dir }}{{ orchestrator_Install_dir_name }}"
.\install.ps1 -URL "{{command_url}}/KeyfactorAgents" -WebCredential $credKeyfactor -OrchestratorName "{{ orchestrator_name }}" -Capabilities all -Force