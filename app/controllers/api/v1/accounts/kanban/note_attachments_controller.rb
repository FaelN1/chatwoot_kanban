class Api::V1::Accounts::Kanban::NoteAttachmentsController < Api::V1::Accounts::BaseController
  before_action :fetch_kanban_item
  
  def create
    Rails.logger.info "Tentando criar anexo para KanbanItem #{params[:kanban_item_id]}"
    Rails.logger.info "Account ID: #{Current.account.id}"
    
    if params[:attachment].blank?
      return render json: { error: 'No attachment provided' }, status: :unprocessable_entity
    end

    attachment = @kanban_item.note_attachments.attach(params[:attachment])
    
    if attachment && @kanban_item.validate_note_attachment(@kanban_item.note_attachments.last)
      render json: {
        id: @kanban_item.note_attachments.last.id,
        attachment_url: url_for(@kanban_item.note_attachments.last),
        message: 'Attachment uploaded successfully'
      }, status: :created
    else
      render json: { error: @kanban_item.errors.full_messages.join(', ') }, 
             status: :unprocessable_entity
    end
  end

  def destroy
    attachment = @kanban_item.note_attachments.find(params[:id])
    attachment.purge
    
    render json: { message: 'Attachment deleted successfully' }
  end

  private

  def fetch_kanban_item
    Rails.logger.info "Buscando KanbanItem com ID: #{params[:item_id] || params[:kanban_item_id] || params[:id]}"
    Rails.logger.info "Account atual: #{Current.account.id}"
    
    item_id = params[:item_id] || params[:kanban_item_id] || params[:id]
    
    @kanban_item = Current.account.kanban_items.find_by(id: item_id)
    
    unless @kanban_item
      Rails.logger.error "KanbanItem não encontrado. IDs disponíveis: #{Current.account.kanban_items.pluck(:id)}"
      render json: { 
        error: 'Kanban item not found',
        debug: {
          account_id: Current.account.id,
          kanban_item_id: item_id,
          params: params.permit!.to_h,
          available_items: Current.account.kanban_items.pluck(:id)
        }
      }, status: :not_found
    end
  end
end 