namespace :budgets do
  desc "Recompute precomputed budget metrics across all budgets"
  task recompute_all: :environment do
    puts "Recomputing budget values..."
    count = 0
    Budget.find_each do |budget|
      budget.recompute_values!
      count += 1
    end
    puts "Successfully recomputed values for #{count} budget(s)."
  end
end
