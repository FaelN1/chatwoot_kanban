class KanbanItemPolicy < ApplicationPolicy
  def index?
    @account_user.administrator? || @account_user.agent?
  end

  def show?
    @account_user.administrator? || @account_user.agent?
  end

  def create?
    @account_user.administrator? || @account_user.agent?
  end

  def update?
    @account_user.administrator? || @account_user.agent?
  end

  def destroy?
    @account_user.administrator?
  end

  def move_to_stage?
    update?
  end

  def reorder?
    update?
  end

  class Scope < Scope
    def resolve
      scope.where(account_id: Current.account.id)
    end
  end
end 