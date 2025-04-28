class SuperAdmin::DashboardScriptsController < SuperAdmin::ApplicationController
  def show
    @dashboard_scripts = InstallationConfig.find_by(name: 'DASHBOARD_SCRIPTS')&.value
  end

  def create
    handle_script_update
    redirect_to super_admin_dashboard_scripts_path, notice: 'Modulos StackLab atualizados com sucesso'
  end

  private

  def handle_script_update
    script_value = params[:dashboard_scripts]
    
    # Garantir que o script esteja em um formato seguro
    script_value = '' if script_value.nil?
    
    # Usar first_or_initialize para encontrar ou criar a configuração
    i = InstallationConfig.where(name: 'DASHBOARD_SCRIPTS').first_or_initialize
    i.locked = false # Garantir que não está bloqueado
    i.value = script_value # Usar o setter para garantir o formato correto
    i.save!
  end
end

SuperAdmin::DashboardScriptsController.prepend_mod_with('SuperAdmin::DashboardScriptsController') 