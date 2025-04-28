module KanbanActivityHandler
  extend ActiveSupport::Concern

  private

  def create_activity(type, details = {})
    Rails.logger.info "KanbanActivityHandler#create_activity chamado com type: #{type}, details: #{details.inspect}"
    
    # Adiciona o usuário atual aos detalhes se não foi fornecido
    details[:user] ||= {
      id: Current.user&.id,
      name: Current.user&.name,
      avatar_url: Current.user&.avatar_url
    }
    
    ::Kanban::ActivityMessageJob.perform_later(self, {
      type: type,
      details: details
    })
  end

  def translate_stage(stage)
    case stage
    when 'lead'
      'Lead'
    when 'qualified'
      'Qualificado'
    when 'proposal'
      'Proposta'
    when 'negotiation'
      'Negociação'
    when 'closed_won'
      'Ganho'
    when 'closed_lost'
      'Perdido'
    else
      stage
    end
  end

  def translate_priority(priority)
    case priority
    when 'none'
      'Nenhuma'
    when 'low'
      'Baixa'
    when 'medium'
      'Média'
    when 'high'
      'Alta'
    when 'urgent'
      'Urgente'
    else
      priority
    end
  end

  def handle_stage_change
    return unless saved_change_to_funnel_stage?

    old_stage, new_stage = previous_changes[:funnel_stage]
    create_activity('stage_changed', {
      old_stage: old_stage,
      new_stage: new_stage,
      user: {
        id: Current.user&.id,
        name: Current.user&.name,
        avatar_url: Current.user&.avatar_url
      }
    })
  end

  def handle_priority_change
    return unless item_details_changed? && 
                  item_details['priority'] != item_details_was['priority']

    create_activity('priority_changed', {
      old_priority: item_details_was['priority'],
      new_priority: item_details['priority']
    })
  end

  def handle_agent_change
    return unless item_details_changed? && 
                  item_details['agent_id'] != item_details_was['agent_id']

    old_agent = User.find_by(id: item_details_was['agent_id'])&.name
    new_agent = User.find_by(id: item_details['agent_id'])&.name

    create_activity('agent_changed', {
      old_agent: old_agent,
      new_agent: new_agent
    })
  end

  def handle_note_added(note_text)
    create_activity('note_added', {
      note_text: note_text.truncate(100)
    })
  end

  def handle_attachment_added(filename)
    create_activity('attachment_added', {
      filename: filename
    })
  end

  def handle_checklist_item_added(item_text)
    create_activity('checklist_item_added', {
      item_text: item_text
    })
  end

  def handle_checklist_item_toggled(item_text, completed)
    create_activity('checklist_item_toggled', {
      item_text: item_text,
      completed: completed
    })
  end

  def handle_value_change
    return unless item_details_changed? && 
                  item_details['value'] != item_details_was['value']

    create_activity('value_changed', {
      old_value: item_details_was['value'],
      new_value: item_details['value'],
      old_currency: item_details_was['currency'],
      new_currency: item_details['currency']
    })
  end

  def handle_conversation_linked
    Rails.logger.info "KanbanActivityHandler#handle_conversation_linked chamado"
    return unless saved_change_to_conversation_display_id?

    old_conversation_id, new_conversation_id = previous_changes[:conversation_display_id]
    
    if new_conversation_id.present?
      conversation = Conversation.find_by(display_id: new_conversation_id)
      create_activity('conversation_linked', {
        conversation_id: new_conversation_id,
        conversation_title: conversation&.inbox&.name || 'Conversa',
        user: {
          id: Current.user&.id,
          name: Current.user&.name,
          avatar_url: Current.user&.avatar_url
        }
      })
    else
      create_activity('conversation_unlinked', {
        conversation_id: old_conversation_id,
        user: {
          id: Current.user&.id,
          name: Current.user&.name,
          avatar_url: Current.user&.avatar_url
        }
      })
    end
  end
end 