defmodule BrowseyHttp.Util.Time do
  @moduledoc false
  @doc """
  Returns the seconds between the given DateTime and now.
  """
  def seconds_since(%DateTime{} = dt, now \\ DateTime.utc_now()) do
    DateTime.diff(now, dt, :second)
  end

  @doc """
  Returns the milliseconds between the given DateTime and now.
  """
  def ms_since(%DateTime{} = dt, now \\ DateTime.utc_now()) do
    DateTime.diff(now, dt, :millisecond)
  end

  @doc """
  Returns the seconds from now until the given DateTime.
  """
  def seconds_until(%DateTime{} = dt, now \\ DateTime.utc_now()) do
    DateTime.diff(dt, now, :second)
  end

  @doc """
  Returns the milliseconds from now until the given DateTime.
  """
  def ms_until(%DateTime{} = dt, now \\ DateTime.utc_now()) do
    DateTime.diff(dt, now, :millisecond)
  end

  @doc """
  Returns a DateTime that's the specified number of seconds in the future.
  """
  @spec seconds_from_now(number, DateTime.t()) :: DateTime.t()
  def seconds_from_now(seconds, now \\ DateTime.utc_now()) do
    DateTime.add(now, round(seconds * 1_000), :millisecond)
  end

  @doc """
  Returns a DateTime that's the specified number of milliseconds in the future.
  """
  @spec ms_from_now(number, DateTime.t()) :: DateTime.t()
  def ms_from_now(milliseconds, now \\ DateTime.utc_now()) do
    DateTime.add(now, milliseconds, :millisecond)
  end

  @doc """
  Returns a DateTime that's the specified number of seconds in the past.
  """
  @spec seconds_ago(number, DateTime.t()) :: DateTime.t()
  def seconds_ago(seconds, now \\ DateTime.utc_now()) do
    DateTime.add(now, -round(seconds * 1_000), :millisecond)
  end

  @doc """
  True if it's currently past the given datetime.

  ## Examples

      iex> Util.Time.deadline_passed?(~U[2000-01-01 12:00:00Z])
      true

      iex> Util.Time.deadline_passed?(~U[2999-01-01 12:00:00Z])
      false
  """
  def deadline_passed?(%DateTime{} = dt, now \\ DateTime.utc_now()) do
    DateTime.after?(now, dt)
  end
end
