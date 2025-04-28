# == Schema Information
#
# Table name: kanban_items
#
#  id                      :bigint           not null, primary key
#  custom_attributes       :jsonb
#  funnel_stage            :string           not null
#  item_details            :jsonb
#  position                :integer          not null
#  stage_entered_at        :datetime
#  timer_duration          :integer          default(0)
#  timer_started_at        :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  account_id              :bigint           not null
#  conversation_display_id :bigint
#  funnel_id               :bigint           not null
#
# Indexes
#
#  index_kanban_items_on_account_id                                 (account_id)
#  index_kanban_items_on_account_id_and_funnel_id_and_funnel_stage  (account_id,funnel_id,funnel_stage)
#  index_kanban_items_on_conversation_display_id                    (conversation_display_id)
#  index_kanban_items_on_funnel_id                                  (funnel_id)
#  index_kanban_items_on_funnel_id_and_funnel_stage                 (funnel_id,funnel_stage)
#
# Foreign Keys
#
#  fk_rails_...  (funnel_id => funnels.id)
#

class KanbanItem < ApplicationRecord
  include Events::Types
  include KanbanActivityHandler

  belongs_to :account
  belongs_to :conversation, foreign_key: :conversation_display_id, 
                          primary_key: :display_id, 
                          class_name: 'Conversation',
                          optional: true
  belongs_to :funnel

  validates :account_id, presence: true
  validates :funnel_id, presence: true
  validates :funnel_stage, presence: true
  validates :position, presence: true

  scope :order_by_position, -> { order(position: :asc) }
  scope :for_account, ->(account_id) { where(account_id: account_id) }
  scope :for_funnel, ->(funnel_id) { 
    if funnel_id.present?
      Rails.logger.info "Filtering by funnel_id: #{funnel_id}"
      where(funnel_id: funnel_id) 
    end
  }
  scope :in_stage, ->(stage) { where(funnel_stage: stage) }

  scope :latest_only, -> { order(created_at: :desc).limit(1) }
  before_create :set_stage_entered_at
  before_save :update_stage_entered_at, if: :funnel_stage_changed?
  after_commit :handle_activity_changes, on: [:create, :update]
  after_commit :handle_conversation_linked, on: [:create, :update]

  has_many_attached :note_attachments
  has_many_attached :attachments
  
  validate :validate_attachments

  def move_to_stage(new_stage, stage_entered_at = nil)
    return if new_stage == funnel_stage

    update(
      funnel_stage: new_stage,
      stage_entered_at: stage_entered_at || Time.current
    )
  end

  def start_timer
    return if timer_started_at.present?

    update(timer_started_at: Time.current)
  end

  def stop_timer
    return unless timer_started_at.present?

    elapsed_time = Time.current - timer_started_at
    update(
      timer_started_at: nil,
      timer_duration: timer_duration + elapsed_time.to_i
    )
  end

  def time_in_current_stage
    return 0 unless stage_entered_at

    (Time.current - stage_entered_at).to_i
  end

  def self.debug_counts
    Rails.logger.info "=== KanbanItem Debug Counts ==="
    Rails.logger.info "Total items: #{count}"
    Rails.logger.info "Items by funnel: #{group(:funnel_id).count}"
    Rails.logger.info "Items by stage: #{group(:funnel_stage).count}"
  end

  def validate_note_attachment(attachment)
    return false unless attachment

    if attachment.blob.byte_size > 40.megabytes
      errors.add(:note_attachments, 'size must be less than 40MB')
      return false
    end

    content_type = attachment.blob.content_type
    if !content_type.in?(%w[image/png image/jpg image/jpeg application/pdf])
      errors.add(:note_attachments, 'must be an image (png, jpg) or PDF')
      return false
    end
    true
  end

  def serialized_attachments
    return [] unless attachments.attached?

    attachments.map do |attachment|
      {
        id: attachment.id,
        url: Rails.application.routes.url_helpers.rails_blob_url(attachment, only_path: true),
        filename: attachment.filename.to_s,
        byte_size: attachment.byte_size,
        content_type: attachment.content_type,
        created_at: attachment.created_at,
        source: {
          type: 'item',
          id: id
        }
      }
    end
  end

  def as_json(options = {})
    super(options)
  end

  def validate_attachments
    return unless attachments.attached?
    
    attachments.each do |attachment|
      unless attachment.content_type.in?(%w[
        image/png image/jpg image/jpeg image/gif 
        application/pdf 
        application/msword application/vnd.openxmlformats-officedocument.wordprocessingml.document
        application/vnd.ms-excel application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
      ])
        errors.add(:attachments, 'deve ser uma imagem (png, jpg, gif), PDF, DOC ou XLS')
      end
      
      if attachment.byte_size > 10.megabytes
        errors.add(:attachments, 'deve ter menos de 10MB')
      end
    end
  end

  private

  def handle_activity_changes
    handle_stage_change
    handle_priority_change
    handle_agent_change
    handle_value_change
  end

  def set_stage_entered_at
    self.stage_entered_at = Time.current
  end

  def update_stage_entered_at
    self.stage_entered_at = Time.current
  end
end 
