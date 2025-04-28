class ScheduledMessageJob < ApplicationJob
  queue_as :scheduled_messages

  def perform(scheduled_message_id)
    scheduled_message = ScheduledMessage.find(scheduled_message_id)
    
    # Criar uma nova conversa com status open
    conversation = ::Conversation.create!(
      account_id: scheduled_message.account_id,
      inbox_id: scheduled_message.inbox_id,
      contact_id: scheduled_message.conversation.contact_id,
      contact_inbox: find_or_create_contact_inbox(scheduled_message),
      status: :open
    )

    # Enviar mensagem na nova conversa
    Messages::MessageBuilder.new(
      scheduled_message.user,
      conversation,
      { 
        content: scheduled_message.content,
        inbox_id: scheduled_message.inbox_id
      }
    ).perform

    scheduled_message.update(status: :sent)
  rescue => e
    scheduled_message.update(status: :failed)
    Rails.logger.error "Failed to send scheduled message #{scheduled_message_id}: #{e.message}"
  end

  private

  def find_or_create_contact_inbox(scheduled_message)
    contact = scheduled_message.conversation.contact
    inbox = Inbox.find(scheduled_message.inbox_id)
    
    ContactInbox.find_or_create_by!(
      contact_id: contact.id,
      inbox_id: scheduled_message.inbox_id,
      source_id: generate_source_id(contact, inbox)
    )
  end

  def generate_source_id(contact, inbox)
    case inbox.channel_type
    when 'Channel::Whatsapp'
      contact.phone_number
    when 'Channel::Email'  
      contact.email
    else
      SecureRandom.uuid
    end
  end
end 