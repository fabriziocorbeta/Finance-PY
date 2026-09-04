require "test_helper"

class GoalsCardComponentTest < ViewComponent::TestCase
  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @goal = Goal.create!(
      family: @family,
      name: "Fondo de emergencia",
      target_amount: 10000,
      target_date: 30.days.from_now.to_date,
      currency: "USD",
      color: "#6471eb"
    )
    @goal.goal_accounts.create!(account: @account)
  end

  test "renders card component in es without translation missing" do
    I18n.with_locale(:es) do
      render_inline(Goals::CardComponent.new(goal: @goal))
      assert_no_match(/Translation missing/i, rendered_content)
      assert_text "1 cuenta"
      assert_text "Fondo de emergencia"
    end
  end

  test "renders card component in en without translation missing" do
    I18n.with_locale(:en) do
      render_inline(Goals::CardComponent.new(goal: @goal))
      assert_no_match(/Translation missing/i, rendered_content)
      assert_text "1 account"
      assert_text "Fondo de emergencia"
    end
  end

  test "renders progress ring component in es without escaping corruption" do
    I18n.with_locale(:es) do
      render_inline(Goals::ProgressRingComponent.new(goal: @goal, size: 180))
      assert_no_match(/Translation missing/i, rendered_content)
      assert_includes rendered_content, 'aria-label="Progreso de la meta:'
      assert_includes rendered_content, 'class="relative mx-auto"'
      assert_includes rendered_content, 'style="width: 180px; height: 180px;"'
    end
  end

  test "renders funding accounts breakdown component in es without translation missing" do
    I18n.with_locale(:es) do
      render_inline(Goals::FundingAccountsBreakdownComponent.new(goal: @goal))
      assert_no_match(/Translation missing/i, rendered_content)
      assert_text "Cuentas de financiamiento"
    end
  end
end
