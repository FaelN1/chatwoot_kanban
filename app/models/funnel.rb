# == Schema Information
#
# Table name: funnels
#
#  id          :bigint           not null, primary key
#  active      :boolean          default(TRUE)
#  description :string
#  name        :string           not null
#  settings    :jsonb
#  stages      :jsonb            not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#
# Indexes
#
#  index_funnels_on_account_id           (account_id)
#  index_funnels_on_account_id_and_name  (account_id,name) UNIQUE
#

class Funnel < ApplicationRecord
  include Events::Types

  belongs_to :account
  has_many :kanban_items, dependent: :destroy_async

  validates :name, presence: true
  validates :name, uniqueness: { scope: :account_id }
  validates :stages, presence: true
  validate :validate_stages_format

  scope :active, -> { where(active: true) }
  scope :ordered_by_name, -> { order(:name) }

  def available_stages
    stages.keys
  end

  def stage_settings(stage_name)
    stages[stage_name] || {}
  end

  private

  def validate_stages_format
    return if stages.blank?
    return if stages.is_a?(Hash)

    errors.add(:stages, 'deve ser um objeto JSON válido')
  end
end 
