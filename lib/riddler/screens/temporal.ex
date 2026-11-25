defmodule Riddler.Screens.Temporal do
  @moduledoc false

  # The `date`, `time` and `datetime` formats of a text question: the one
  # reading of each that admission holds a bound to and response validation
  # holds a response to, so the two cannot disagree about what a date is.
  #
  #   * `date` is `YYYY-MM-DD`, a calendar date that exists;
  #   * `time` is `HH:MM` or `HH:MM:SS`, 24-hour, hours `00` to `23`, minutes
  #     and seconds `00` to `59`;
  #   * `datetime` is a `date` and a `time` joined by `T`, then `Z` or an
  #     offset `+HH:MM` or `-HH:MM`.
  #
  # No fraction of a second, no lower-case `t` or `z`, no week or ordinal date
  # and no other ISO 8601 form. Nothing is trimmed here: a caller that reads
  # the text with the whitespace around it set aside trims it first.
  #
  # Each value reads as an integer that orders as the value does: a date as
  # its day in the proleptic Gregorian calendar, a time as its second of the
  # day, so that `HH:MM` is the same time as `HH:MM:00`, and a datetime as the
  # second of the instant it names, its offset taken away, so that
  # `2026-11-24T16:30:00Z` and `2026-11-24T09:30:00-07:00` are equal. Only the
  # standard library reads them.
  #
  # No part of the package's surface.

  @formats ["date", "time", "datetime"]

  @date ~r/\A(\d{4})-(\d{2})-(\d{2})\z/
  @time ~r/\A([01]\d|2[0-3]):([0-5]\d)(?::([0-5]\d))?\z/
  @datetime ~r/\A(\d{4}-\d{2}-\d{2})T([^Z+\-]+)(Z|[+\-]\d{2}:\d{2})\z/
  @offset ~r/\A([+\-])([01]\d|2[0-3]):([0-5]\d)\z/

  @seconds_per_day 86_400

  @doc false
  @spec formats() :: [String.t()]
  def formats, do: @formats

  @doc false
  @spec format?(term()) :: boolean()
  def format?(format), do: format in @formats

  # The value a string names in its format, as an integer that orders as the
  # value does, or `:error` where it is not a string in the format's shape.
  @doc false
  @spec read(String.t(), term()) :: {:ok, integer()} | :error
  def read("date", text) when is_binary(text), do: date(text)
  def read("time", text) when is_binary(text), do: time(text)
  def read("datetime", text) when is_binary(text), do: datetime(text)
  def read(_format, _text), do: :error

  defp date(text) do
    with [_whole, year, month, day] <- Regex.run(@date, text),
         {:ok, date} <-
           Date.new(String.to_integer(year), String.to_integer(month), String.to_integer(day)) do
      {:ok, Date.to_gregorian_days(date)}
    else
      _not_a_date -> :error
    end
  end

  defp time(text) do
    case Regex.run(@time, text) do
      [_whole, hours, minutes] -> {:ok, seconds(hours, minutes, "00")}
      [_whole, hours, minutes, seconds] -> {:ok, seconds(hours, minutes, seconds)}
      nil -> :error
    end
  end

  defp seconds(hours, minutes, seconds) do
    String.to_integer(hours) * 3600 + String.to_integer(minutes) * 60 +
      String.to_integer(seconds)
  end

  defp datetime(text) do
    with [_whole, date_text, time_text, zone] <- Regex.run(@datetime, text),
         {:ok, days} <- date(date_text),
         {:ok, seconds} <- time(time_text),
         {:ok, offset} <- offset(zone) do
      {:ok, days * @seconds_per_day + seconds - offset}
    else
      _not_a_datetime -> :error
    end
  end

  defp offset("Z"), do: {:ok, 0}

  defp offset(zone) do
    case Regex.run(@offset, zone) do
      [_whole, "+", hours, minutes] -> {:ok, seconds(hours, minutes, "00")}
      [_whole, "-", hours, minutes] -> {:ok, -seconds(hours, minutes, "00")}
      nil -> :error
    end
  end
end
