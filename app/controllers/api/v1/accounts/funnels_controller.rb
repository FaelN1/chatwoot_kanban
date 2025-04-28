class Api::V1::Accounts::FunnelsController < Api::V1::Accounts::BaseController
  before_action :fetch_funnel, except: [:index, :create]
  before_action :check_funnel_limit, only: [:create]

  def index
    @funnels = Current.account.funnels.ordered_by_name
    render json: @funnels
  end

  def show
    render json: @funnel
  end

  def create
    @funnel = Current.account.funnels.new(funnel_params)
    
    if @funnel.stages.present?
      # Busca todos os IDs de etapas existentes em todos os funis
      existing_stage_ids = Current.account.funnels.pluck(:stages).compact.flat_map do |stages|
        stages.values.map { |stage| stage['id'] }
      end

      # Ajusta os IDs das etapas e seus templates
      @funnel.stages = @funnel.stages.transform_values do |stage|
        if existing_stage_ids.include?(stage['id'])
          new_id = "#{stage['id']}_#{Time.now.to_i}"
          stage.merge('id' => new_id)
        else
          stage
        end
      end
    end

    if @funnel.save
      render json: @funnel
    else
      render json: { errors: @funnel.errors }, status: :unprocessable_entity
    end
  end

  def update
    if @funnel.update(funnel_params)
      render json: @funnel
    else
      render json: { errors: @funnel.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    @funnel.destroy!
    head :ok
  end

  private

  def fetch_funnel
    @funnel = Current.account.funnels.find(params[:id])
  end

  def funnel_params
    params.require(:funnel).permit(
      :name,
      :description,
      :active,
      stages: {},
      settings: {}
    )
  end

  def check_funnel_limit
    # Usa ChatwootApp.stacklab ao invés de ENV
    return if ChatwootApp.stacklab?

    if Current.account.funnels.count >= 2
      render json: { 
        error: 'Limite de funis atingido. Atualize para a versão PRO para criar mais funis.',
        code: 'FUNNEL_LIMIT_REACHED'
      }, status: :forbidden
    end
  end
end 