excluded_tags = [:integration, :local_integration, :scraping_todo, :todo]
ExUnit.start(exclude: excluded_tags, max_cases: System.schedulers_online() * 2)
