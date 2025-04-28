class Kanban::ActivityMessageJob < ApplicationJob
  queue_as :high

  def perform(kanban_item, activity_params)
    Rails.logger.info "Iniciando Kanban::ActivityMessageJob para item #{kanban_item.id}"
    return unless kanban_item

    # Garante que temos um array de atividades
    kanban_item.item_details['activities'] ||= []
    
    # Cria a nova atividade com o usuário dos detalhes ou o usuário atual
    new_activity = {
      id: Time.current.to_i,
      type: activity_params[:type],
      details: activity_params[:details],
      created_at: Time.current.iso8601,
      user: activity_params[:details][:user] || {
        id: Current.user&.id,
        name: Current.user&.name,
        avatar_url: Current.user&.avatar_url
      }
    }

    Rails.logger.info "Registrando atividade: #{new_activity.inspect}"

    # Adiciona a nova atividade ao array
    activities = kanban_item.item_details['activities'] + [new_activity]

    # Atualiza o item do kanban com a nova atividade
    kanban_item.update!(
      item_details: kanban_item.item_details.merge('activities' => activities)
    )

    # Se houver uma conversa vinculada, registra a atividade também na conversa
    if kanban_item.conversation.present?
      Rails.logger.info "Registrando atividade na conversa #{kanban_item.conversation.display_id}"
      content = generate_conversation_activity_content(activity_params, new_activity[:user])
      ::Conversations::ActivityMessageJob.perform_later(
        kanban_item.conversation,
        {
          account_id: kanban_item.account_id,
          inbox_id: kanban_item.conversation.inbox_id,
          message_type: :activity,
          content: content
        }
      )
    end
  rescue StandardError => e
    Rails.logger.error "Erro no Kanban::ActivityMessageJob: #{e.message}\n#{e.backtrace.join("\n")}"
    raise e
  end

  private

  def generate_conversation_activity_content(activity_params, user)
    user_name = user[:name] || 'Sistema'
    
    case activity_params[:type]
    when 'stage_changed'
      "#{user_name} moveu o item do Kanban para #{activity_params[:details][:new_stage]}"
    when 'priority_changed'
      "#{user_name} alterou a prioridade do item do Kanban para #{activity_params[:details][:new_priority]}"
    when 'agent_changed'
      "#{user_name} atribuiu o item do Kanban para #{activity_params[:details][:new_agent]}"
    when 'note_added'
      "#{user_name} adicionou uma nota ao item do Kanban: #{activity_params[:details][:note_text]}"
    when 'conversation_linked'
      "#{user_name} vinculou o item do Kanban à conversa"
    when 'conversation_unlinked'
      "#{user_name} desvinculou o item do Kanban da conversa"
    else
      "#{user_name} atualizou o item do Kanban"
    end
  end
end 