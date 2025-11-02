ExUnit.start()

# Load test support modules
Code.require_file("test/support/data_case.ex")
Code.require_file("test/support/conn_case.ex")

Ecto.Adapters.SQL.Sandbox.mode(Emailgator.Repo, :manual)
