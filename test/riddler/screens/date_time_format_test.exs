defmodule Riddler.Screens.DateTimeFormatTest do
  use ExUnit.Case, async: true

  alias Riddler.Finding
  alias Riddler.Screens
  alias Riddler.Screens.Document
  alias Riddler.Screens.Temporal
  alias Riddler.Screens.Type.TextQuestion

  defp raw(elements) do
    %{
      "schema_version" => 2,
      "id" => "edoc_signup_screens",
      "screens" => [
        %{"key" => "account", "title" => "Create your account", "elements" => elements}
      ]
    }
  end

  defp document(elements), do: Document.admit(raw(elements))

  defp findings(elements) do
    case Document.validate(document(elements)) do
      {:ok, _document} -> []
      {:error, findings} -> Enum.map(findings, &{&1.code, &1.element_key, &1.field})
    end
  end

  defp question(format, overrides \\ %{}) do
    Map.merge(
      %{
        "type" => "text_question",
        "key" => "trial_start",
        "label" => "Start your trial on",
        "format" => format
      },
      overrides
    )
  end

  defp check(question, response) do
    Screens.validate_screen(document([question]), "account", %{
      "responses" => %{"trial_start" => response}
    })
  end

  defp codes(question, response) do
    case check(question, response) do
      :ok -> :ok
      {:error, findings} -> Enum.map(findings, &{&1.code, &1.field})
    end
  end

  describe "admission" do
    # Sabotage: removed "date", "time" and "datetime" from the formats the
    # document knows; each was document.unknown_format and this test went red.
    test "date, time and datetime are formats the document knows, with bounds in their shape" do
      assert findings([question("date", %{"min" => "2026-01-01", "max" => "2026-12-31"})]) == []
      assert findings([question("time", %{"min" => "09:00", "max" => "17:30:00"})]) == []

      assert findings([
               question("datetime", %{
                 "min" => "2026-11-24T09:00:00Z",
                 "max" => "2026-11-24T17:00-07:00"
               })
             ]) == []
    end

    # Sabotage: made the temporal clause of `bound_findings/1` answer `[]`;
    # every bound out of its format's shape was admitted and this test went
    # red.
    test "a date or time bound not in its format's shape is refused, naming the bound" do
      assert findings([question("date", %{"max" => "24/11/2026"})]) ==
               [{"document.invalid_bound", "trial_start", "max"}]

      assert findings([question("date", %{"max" => 20_261_124})]) ==
               [{"document.invalid_bound", "trial_start", "max"}]

      assert findings([question("date", %{"min" => "2026-02-30"})]) ==
               [{"document.invalid_bound", "trial_start", "min"}]

      assert findings([question("time", %{"min" => "9:00"})]) ==
               [{"document.invalid_bound", "trial_start", "min"}]

      assert findings([question("datetime", %{"min" => "2026-11-24T09:00:00", "max" => "x"})]) ==
               [
                 {"document.invalid_bound", "trial_start", "min"},
                 {"document.invalid_bound", "trial_start", "max"}
               ]
    end

    # Sabotage: made the `min > max` guard of `temporal_bound_findings/2`
    # always false; the min after its max was admitted and this test went red.
    test "a date or time min after its max is refused on the max, and an equal pair is admitted" do
      assert findings([question("date", %{"min" => "2026-12-01", "max" => "2026-11-24"})]) ==
               [{"document.invalid_bound", "trial_start", "max"}]

      assert findings([question("time", %{"min" => "17:00", "max" => "09:00:00"})]) ==
               [{"document.invalid_bound", "trial_start", "max"}]

      # Compared as instants: 09:30 at UTC-7 is after 16:00 UTC.
      assert findings([
               question("datetime", %{
                 "min" => "2026-11-24T09:30:00-07:00",
                 "max" => "2026-11-24T16:00:00Z"
               })
             ]) == [{"document.invalid_bound", "trial_start", "max"}]

      assert findings([question("time", %{"min" => "09:00", "max" => "09:00:00"})]) == []
    end

    # Sabotage: made the filter of `numeric_bound_findings/1` always false; the
    # string bounds on the numeric formats were admitted and this test went red.
    test "a numeric format's bound that is not a number is refused, and a min above its max is not" do
      seats = %{"key" => "seat_count", "label" => "Seats"}

      assert findings([question("integer", Map.merge(seats, %{"min" => "18"}))]) ==
               [{"document.invalid_bound", "seat_count", "min"}]

      assert findings([question("number", Map.merge(seats, %{"min" => 0, "max" => nil}))]) ==
               [{"document.invalid_bound", "seat_count", "max"}]

      assert findings([question("integer", Map.merge(seats, %{"min" => 10, "max" => 2}))]) == []
      assert findings([question("number", Map.merge(seats, %{"min" => 0.5, "max" => 2}))]) == []
    end

    # Sabotage: made `bound_findings/1` take the date and time clause for every
    # format the numeric clause does not; the email question's bound was
    # refused and this test went red.
    test "a bound under a format that does not read it, or under none, is consulted by nothing" do
      assert findings([question("email", %{"min" => "anything"})]) == []

      assert findings([
               %{
                 "type" => "text_question",
                 "key" => "nickname",
                 "label" => "Nickname",
                 "max" => []
               }
             ]) == []
    end

    # Sabotage: removed "datetime" from the formats the document knows; the
    # date and time formats it reads were no longer all formats it admits,
    # and this test went red.
    test "every date and time format is a format the document knows" do
      assert Enum.all?(Temporal.formats(), &(&1 in Document.formats()))
    end

    # Sabotage: same mutation as the first admission test; the finding named
    # the five formats only and this test went red.
    test "the unknown-format message names the date and time formats" do
      [%Finding{code: "document.unknown_format", message: message}] =
        document([question("calendar")]).screens
        |> hd()
        |> Map.fetch!(:elements)
        |> hd()
        |> TextQuestion.validate()

      assert message =~ "date, time, datetime"
    end
  end

  describe "a date response" do
    # Sabotage: made the date reading clamp the day to 28 before `Date.new/3`;
    # the thirtieth of February was accepted and this test went red.
    test "is a calendar date that exists, in YYYY-MM-DD, read with the whitespace set aside" do
      q = question("date")

      assert codes(q, "1990-04-17") == :ok
      assert codes(q, " 1990-04-17 ") == :ok
      assert codes(q, "1990-02-30") == [{"response.format", "format"}]
      assert codes(q, "17/04/1990") == [{"response.format", "format"}]
      assert codes(q, "1990-4-17") == [{"response.format", "format"}]
      assert codes(q, 19_900_417) == [{"response.format", "format"}]
    end

    # Sabotage: made `bound_after?/2` answer `false` always; the date before
    # the min was accepted and this test went red.
    test "is held between its bounds, both inclusive" do
      q = question("date", %{"min" => "1900-01-01", "max" => "2026-11-24"})

      assert codes(q, "1900-01-01") == :ok
      assert codes(q, "2026-11-24") == :ok
      assert codes(q, "1890-01-01") == [{"response.out_of_range", "min"}]
      assert codes(q, "2031-04-17") == [{"response.out_of_range", "max"}]
    end

    # Sabotage: made `checks/2` put a blank response to its format; the blank
    # date was response.format and this test went red.
    test "a blank response is the business of required alone" do
      assert codes(question("date", %{"min" => "2026-01-01"}), "  ") == :ok

      assert codes(question("date", %{"required" => true}), "") == [
               {"response.required", "required"}
             ]
    end
  end

  describe "a time response" do
    # Sabotage: made the time reading ignore the seconds; 09:00:30 read as
    # 09:00, fell under the min of 09:00:01, and this test went red.
    test "is HH:MM or HH:MM:SS, 24-hour, and HH:MM is HH:MM:00" do
      q = question("time", %{"min" => "09:00:01", "max" => "17:30"})

      assert codes(q, "17:30:00") == :ok
      assert codes(q, "17:30") == :ok
      assert codes(q, "09:00:30") == :ok
      assert codes(q, "09:00") == [{"response.out_of_range", "min"}]
      assert codes(q, "17:30:01") == [{"response.out_of_range", "max"}]
      assert codes(q, "24:00") == [{"response.format", "format"}]
      assert codes(q, "9:30") == [{"response.format", "format"}]
      assert codes(q, "09:30:00.5") == [{"response.format", "format"}]
    end

    # Sabotage: loosened the seconds of the time expression to two digits;
    # 09:00:60 was read as a time and this test went red.
    test "is held to its min inclusively, and a second past 59 or a number is not a time" do
      q = question("time", %{"min" => "09:00:01"})

      assert codes(q, "09:00:01") == :ok
      assert codes(q, " 09:00:01 ") == :ok
      assert codes(q, "09:00:60") == [{"response.format", "format"}]
      assert codes(q, 930) == [{"response.format", "format"}]
    end
  end

  describe "a datetime response" do
    # Sabotage: made the offset add rather than take away; the instant at
    # UTC-7 read fourteen hours off and this test went red.
    test "is compared as the instant it names" do
      q = question("datetime", %{"max" => "2026-11-24T16:30:00Z"})

      assert codes(q, "2026-11-24T09:30:00-07:00") == :ok
      assert codes(q, "2026-11-24T16:30Z") == :ok
      assert codes(q, "2026-11-24T09:30:01-07:00") == [{"response.out_of_range", "max"}]
      assert codes(q, "2026-11-24T17:30:00+01:00") == :ok
    end

    # Sabotage: same mutation as above; the instant at UTC-7 read fourteen
    # hours early, fell under the min, and this test went red.
    test "is held to its min as an instant, inclusively" do
      q = question("datetime", %{"min" => "2026-11-24T16:30:00Z"})

      assert codes(q, "2026-11-24T09:30:00-07:00") == :ok
      assert codes(q, " 2026-11-24T16:30:00Z ") == :ok
      assert codes(q, "2026-11-24T09:29:59-07:00") == [{"response.out_of_range", "min"}]
    end

    # Sabotage: made the datetime expression case-insensitive; the lower-case
    # t was accepted and this test went red.
    test "takes Z or an offset, in upper case, with no fraction of a second" do
      q = question("datetime")

      assert codes(q, "2026-11-24T09:30:00") == [{"response.format", "format"}]
      assert codes(q, "2026-11-24t09:30:00Z") == [{"response.format", "format"}]
      assert codes(q, "2026-11-24T09:30:00z") == [{"response.format", "format"}]
      assert codes(q, "2026-11-24T09:30:00.000Z") == [{"response.format", "format"}]
      assert codes(q, "2026-11-24T09:30:00+0700") == [{"response.format", "format"}]
      assert codes(q, "2026-11-24 09:30:00Z") == [{"response.format", "format"}]
    end

    # Sabotage: loosened the offset expression's hours to any two digits; the
    # offset +24:00 was read and this test went red.
    test "names a date that exists and an offset within a day" do
      q = question("datetime")

      assert codes(q, "2026-02-30T09:00Z") == [{"response.format", "format"}]
      assert codes(q, "2026-11-24T09:00+24:00") == [{"response.format", "format"}]
      assert codes(q, "2026-11-24T09:00-07:60") == [{"response.format", "format"}]
      assert codes(q, "2026-11-24T09:00+14:00") == :ok
    end
  end

  describe "a bound refused at admit" do
    # Sabotage: made `under?/2` read a string bound with `String.to_integer/1`;
    # the string bound bounded the response and this test went red.
    test "bounds nothing at validation, for a host that skipped the document checks" do
      q = %{
        "type" => "text_question",
        "key" => "trial_start",
        "label" => "Seats",
        "format" => "integer",
        "min" => "18"
      }

      assert codes(q, "3") == :ok
    end

    # Sabotage: made the unread clauses of `bound_after?/2` and
    # `bound_before?/2` answer `true`; a date inside no real bound was refused
    # as out of range and this test went red.
    test "a date or time bound not in its shape bounds nothing at validation" do
      for {format, response} <- [
            {"date", "2026-01-01"},
            {"time", "09:00"},
            {"datetime", "2026-01-01T09:00:00Z"}
          ] do
        assert codes(question(format, %{"min" => "soon"}), response) == :ok
        assert codes(question(format, %{"max" => "later"}), response) == :ok
      end
    end
  end
end
