class Api::V1::Accounts::Kanban::AttachmentsController < Api::V1::Accounts::BaseController
  before_action :fetch_kanban_item
  
  def create
    if params[:attachment].blank?
      return render json: { error: 'No attachment provided' }, status: :unprocessable_entity
    end

    attachment = @kanban_item.attachments.attach(params[:attachment])
    
    if attachment && @kanban_item.validate_attachments
      render json: {
        id: @kanban_item.attachments.last.id,
        attachment_url: url_for(@kanban_item.attachments.last),
        message: 'Attachment uploaded successfully'
      }, status: :created
    else
      render json: { error: @kanban_item.errors.full_messages.join(', ') }, 
             status: :unprocessable_entity
    end
  end

  def destroy
    updated_attachments = @kanban_item.item_details['attachments'].reject { |a| a['id'].to_s == params[:id].to_s }
    
    if @kanban_item.update(
      item_details: @kanban_item.item_details.merge('attachments' => updated_attachments)
    )
      render json: @kanban_item
    else
      render json: { error: 'Could not delete attachment' }, status: :unprocessable_entity
    end
  end
  
  private
  
  def fetch_kanban_item
    @kanban_item = Current.account.kanban_items.find(params[:item_id])
  end
end 