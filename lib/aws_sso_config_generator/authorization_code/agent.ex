defmodule AwsSsoConfigGenerator.AuthorizationCode.Agent do
  use Agent

  def start_link(_) do
    Agent.start_link(fn -> nil end, name: __MODULE__)
  end

  def get do
    Agent.get(__MODULE__, & &1)
  end

  def set(value) do
    Agent.update(__MODULE__, fn _ -> value end)
  end
end
