# == Schema Information
#
# Table name: scheduled_messages
#
#  id              :bigint           not null, primary key
#  content         :text             not null
#  scheduled_at    :datetime         not null
#  status          :string           default("pending")
#  title           :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  conversation_id :bigint           not null
#  inbox_id        :bigint           not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_scheduled_messages_on_account_id       (account_id)
#  index_scheduled_messages_on_conversation_id  (conversation_id)
#  index_scheduled_messages_on_inbox_id         (inbox_id)
#  index_scheduled_messages_on_scheduled_at     (scheduled_at)
#  index_scheduled_messages_on_status           (status)
#  index_scheduled_messages_on_user_id          (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#  fk_rails_...  (user_id => users.id)
#
class ScheduledMessage < ApplicationRecord
  belongs_to :account
  belongs_to :inbox
  belongs_to :conversation
  belongs_to :user

  validates :content, presence: true
  validates :scheduled_at, presence: true
  validates :status, presence: true

  enum status: { pending: 'pending', sent: 'sent', failed: 'failed' }, _prefix: true

  after_create :schedule_message
  after_initialize :set_default_status, if: :new_record?
  
  private

  def schedule_message
    ScheduledMessageJob.set(wait_until: scheduled_at).perform_later(id)
  end

  def set_default_status
    self.status ||= 'pending'
  end
end 
