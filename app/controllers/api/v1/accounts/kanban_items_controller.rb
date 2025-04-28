class Api::V1::Accounts::KanbanItemsController < Api::V1::Accounts::BaseController
  before_action :fetch_kanban_item, except: [:index, :create, :reorder, :debug]

  def index
    authorize KanbanItem
    funnel_id = params[:funnel_id]
    
    # Buscando os itens do funnel
    items = Current.account.kanban_items
      .for_funnel(funnel_id)
      .includes(:attachments_attachments, :funnel)
      .order_by_position
      .to_a
    
    # Aplicando cache em cada item individualmente
    @kanban_items_data = items.map do |item|
      Rails.cache.fetch([item.id, item.updated_at.to_i], expires_in: 5.minutes) do
        # Serialização do item quando não estiver em cache
        item.as_json
      end
    end

    render json: @kanban_items_data
  end

  def show
    authorize @kanban_item
    
    # Cache baseado no id e updated_at
    @kanban_item_data = Rails.cache.fetch([@kanban_item.id, @kanban_item.updated_at.to_i], expires_in: 5.minutes) do
      @kanban_item.as_json
    end
    
    render json: @kanban_item_data
  end

  def create
    @kanban_item = Current.account.kanban_items.new(kanban_item_params)
    
    # Se houver um conversation_id nos item_details, define o conversation_display_id
    if @kanban_item.item_details['conversation_id'].present?
      @kanban_item.conversation_display_id = @kanban_item.item_details['conversation_id']
    end

    authorize @kanban_item
    
    # Serializa os dados relacionados antes de salvar
    serialize_related_data(@kanban_item)
    
    if @kanban_item.save
      render json: @kanban_item
    else
      render json: { errors: @kanban_item.errors }, status: :unprocessable_entity
    end
  end

  def update
    authorize @kanban_item
    
    # Se houver um conversation_id nos item_details, define o conversation_display_id
    if kanban_item_params.dig(:item_details, 'conversation_id').present?
      params[:kanban_item][:conversation_display_id] = kanban_item_params.dig(:item_details, 'conversation_id')
    end

    # Atualiza os atributos mas não salva ainda
    @kanban_item.assign_attributes(kanban_item_params)
    
    # Serializa os dados relacionados antes de salvar
    serialize_related_data(@kanban_item)

    if @kanban_item.save # updated_at muda automaticamente, invalidando o cache
      render json: @kanban_item
    else
      render json: { errors: @kanban_item.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @kanban_item
    @kanban_item.destroy!
    head :ok
  end

  def move_to_stage
    authorize @kanban_item, :move_to_stage?
    @kanban_item.move_to_stage(params[:funnel_stage])
    head :ok
  end

  def reorder
    authorize KanbanItem, :reorder?
    
    ActiveRecord::Base.transaction do
      params[:positions].each do |position|
        item = Current.account.kanban_items.find(position[:id])
        item.update!(
          position: position[:position],
          funnel_stage: position[:funnel_stage]
        )
        # O updated_at é atualizado automaticamente, invalidando o cache
      end
    end
    
    head :ok
  end

  def debug
    authorize KanbanItem
    funnel_id = params[:funnel_id]
    
    kanban_items = Current.account.kanban_items
                          .for_funnel(funnel_id)
                          .order_by_position
    
    debug_info = {
      environment: Rails.env,
      ruby_version: RUBY_VERSION,
      rails_version: Rails::VERSION::STRING,
      kanban_items_count: kanban_items.size,
      first_item_sample: kanban_items.first&.as_json,
      has_conversation_data: kanban_items.any? { |item| item.item_details['conversation_id'].present? }
    }
    
    render json: debug_info
  end

  private

  def serialize_related_data(kanban_item)
    # Garantir que item_details seja um hash
    kanban_item.item_details = {} unless kanban_item.item_details.is_a?(Hash)
    
    # Serializar attachments
    kanban_item.item_details['attachments'] = kanban_item.serialized_attachments
    
    # Serializar dados do funil
    funnel = kanban_item.funnel
    kanban_item.item_details['funnel'] = {
      id: funnel.id,
      name: funnel.name,
      description: funnel.description,
      active: funnel.active,
      stages: funnel.stages,
      settings: funnel.settings
    }
    
    # Buscar e serializar dados da conversa
    if kanban_item.conversation_display_id.present?
      conversation = Current.account.conversations.find_by(display_id: kanban_item.conversation_display_id)
      
      if conversation
        # Atualizar o campo conversation_id no item_details
        kanban_item.item_details['conversation_id'] = conversation.id
        
        # Serializar dados da conversa
        kanban_item.item_details['conversation'] = {
          id: conversation.id,
          display_id: conversation.display_id,
          inbox_id: conversation.inbox_id,
          account_id: conversation.account_id,
          status: conversation.status,
          priority: conversation.priority,
          team_id: conversation.team_id,
          campaign_id: conversation.campaign_id,
          snoozed_until: conversation.snoozed_until,
          waiting_since: conversation.waiting_since,
          first_reply_created_at: conversation.first_reply_created_at,
          last_activity_at: conversation.last_activity_at,
          additional_attributes: conversation.additional_attributes,
          custom_attributes: conversation.custom_attributes,
          uuid: conversation.uuid,
          created_at: conversation.created_at,
          updated_at: conversation.updated_at,
          label_list: conversation.cached_label_list_array,
          unread_count: conversation.unread_messages.count,
          assignee: conversation.assignee.present? ? {
            id: conversation.assignee.id,
            name: conversation.assignee.name,
            email: conversation.assignee.email,
            avatar_url: conversation.assignee.avatar_url,
            availability_status: conversation.assignee.availability_status
          } : nil,
          contact: conversation.contact.present? ? {
            id: conversation.contact.id,
            name: conversation.contact.name,
            email: conversation.contact.email,
            phone_number: conversation.contact.phone_number,
            thumbnail: conversation.contact.avatar_url,
            additional_attributes: conversation.contact.additional_attributes
          } : nil,
          messages_count: conversation.messages.count,
          inbox: {
            id: conversation.inbox.id,
            name: conversation.inbox.name,
            channel_type: conversation.inbox.channel_type
          }
        }
      end
    elsif kanban_item.item_details['conversation_id'].present?
      conversation = Current.account.conversations.find_by(id: kanban_item.item_details['conversation_id'])
      
      if conversation
        # Serializar dados da conversa
        kanban_item.item_details['conversation'] = {
          id: conversation.id,
          display_id: conversation.display_id,
          inbox_id: conversation.inbox_id,
          account_id: conversation.account_id,
          status: conversation.status,
          priority: conversation.priority,
          team_id: conversation.team_id,
          campaign_id: conversation.campaign_id,
          snoozed_until: conversation.snoozed_until,
          waiting_since: conversation.waiting_since,
          first_reply_created_at: conversation.first_reply_created_at,
          last_activity_at: conversation.last_activity_at,
          additional_attributes: conversation.additional_attributes,
          custom_attributes: conversation.custom_attributes,
          uuid: conversation.uuid,
          created_at: conversation.created_at,
          updated_at: conversation.updated_at,
          label_list: conversation.cached_label_list_array,
          unread_count: conversation.unread_messages.count,
          assignee: conversation.assignee.present? ? {
            id: conversation.assignee.id,
            name: conversation.assignee.name,
            email: conversation.assignee.email,
            avatar_url: conversation.assignee.avatar_url,
            availability_status: conversation.assignee.availability_status
          } : nil,
          contact: conversation.contact.present? ? {
            id: conversation.contact.id,
            name: conversation.contact.name,
            email: conversation.contact.email,
            phone_number: conversation.contact.phone_number,
            thumbnail: conversation.contact.avatar_url,
            additional_attributes: conversation.contact.additional_attributes
          } : nil,
          messages_count: conversation.messages.count,
          inbox: {
            id: conversation.inbox.id,
            name: conversation.inbox.name,
            channel_type: conversation.inbox.channel_type
          }
        }
      end
    end
    
    # Serializar dados do agente
    if kanban_item.item_details['agent_id'].present?
      agent = User.find_by(id: kanban_item.item_details['agent_id'])
      
      if agent
        kanban_item.item_details['agent'] = {
          id: agent.id,
          name: agent.name,
          email: agent.email,
          avatar_url: agent.avatar_url,
          availability_status: agent.availability_status
        }
      end
    end
  end

  def fetch_kanban_item
    @kanban_item = Current.account.kanban_items.find(params[:id])
  end

  def kanban_item_params
    params.require(:kanban_item).permit(
      :funnel_id,
      :funnel_stage,
      :position,
      :conversation_display_id,
      :timer_started_at,
      :timer_duration,
      custom_attributes: {},
      item_details: {}
    )
  end

end