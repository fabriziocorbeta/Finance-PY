require './config/environment'

tables_without_bypass = ActiveRecord::Base.connection.execute(<<~SQL).to_a.map { |r| r["table_name"] }
  SELECT DISTINCT c.relname AS table_name
  FROM pg_class c
  WHERE c.relforcerowsecurity = true
    AND NOT EXISTS (
      SELECT 1 FROM pg_policy p
      WHERE p.polrelid = c.oid
        AND (
          (p.polqual IS NOT NULL AND pg_get_expr(p.polqual, p.polrelid) ILIKE '%app.rls_auth_bypass%')
          OR
          (p.polwithcheck IS NOT NULL AND pg_get_expr(p.polwithcheck, p.polrelid) ILIKE '%app.rls_auth_bypass%')
        )
    )
SQL

justified_tables = tables_without_bypass.sort
justified_with_comments = {}

justified_tables.each do |t|
  # We need to find ONE file and line where it is used. We can grep for the model name or table name in controllers or models?
  # The easiest is to grep for the pluralized model name (e.g. `accounts`, `transactions`) in controllers,
  # or grep `Current.family.#{t}`
  model = t.singularize.camelize
  res = `grep -n "Current.family.#{t}" app/controllers/ -R | head -n 1`.strip
  if res.empty?
    res = `grep -n "#{model}\." app/controllers/ -R | head -n 1`.strip
  end
  if res.empty?
    res = `grep -n "#{t}" app/controllers/ -R | head -n 1`.strip
  end
  if res.empty?
    res = `grep -n "#{model}\." app/models/ -R | head -n 1`.strip
  end
  if res.empty?
    res = `grep -n "#{t}" app/models/ -R | head -n 1`.strip
  end

  justified_with_comments[t] = res.split(':').first(2).join(':') if !res.empty?
end

justified_with_comments.each do |k, v|
  puts "    \"#{k}\" => \"#{v}\","
end
