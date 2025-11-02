defmodule Emailgator.Mocks do
  @moduledoc """
  Defines mocks for external services (Gmail API, OpenAI, Sidecar).
  """
  import Mox

  defmock(Emailgator.GmailMock, for: Emailgator.GmailBehaviour)
  defmock(Emailgator.LLMMock, for: Emailgator.LLMBehaviour)
  defmock(Emailgator.SidecarMock, for: Emailgator.SidecarBehaviour)
end
