defmodule StorexTest.Diff do
  use ExUnit.Case
  doctest Storex

  defmodule Struct do
    defstruct [:name, :age]
  end

  test "diff binary" do
    assert [%{a: "u", p: [], t: "b"}] = Storex.Diff.check("a", "b")
  end

  test "diff tuple" do
    assert [%{a: "u", p: [], t: :b}] = Storex.Diff.check(:a, :b)
  end

  test "diff integer" do
    assert [%{a: "u", p: [], t: 2}] = Storex.Diff.check(1, 2)
  end

  test "diff float" do
    assert [%{a: "u", p: [], t: 1.1}] = Storex.Diff.check(1, 1.1)
  end

  test "diff boolean" do
    assert [%{a: "u", p: [], t: true}] = Storex.Diff.check(false, true)
  end

  test "diff list" do
    assert [%{a: "i", p: [2], t: 3}, %{a: "d", p: [1, 1]}, %{a: "u", p: [0], t: 2}] =
             Storex.Diff.check([1, [1, 2]], [2, [1], 3])
  end

  test "diff map" do
    assert [%{a: "i", p: [:c], t: "c"}, %{a: "d", p: [:b]}, %{a: "u", p: [:a], t: 1}] =
             Storex.Diff.check(%{a: "a", b: "b"}, %{a: 1, c: "c"})
  end

  test "diff struct" do
    assert [%{a: "u", p: [:name], t: "B"}, %{a: "u", p: [:age], t: 10}] =
             Storex.Diff.check(%Struct{name: "A"}, %Struct{name: "B", age: 10})
  end

  test "diff DateTime" do
    assert [%{a: "u", p: [], t: "2000-02-29 23:10:00+01:00 CET Europe/Warsaw"}] =
             Storex.Diff.check(
               %DateTime{
                 year: 2000,
                 month: 2,
                 day: 29,
                 zone_abbr: "CET",
                 hour: 22,
                 minute: 0,
                 second: 7,
                 microsecond: {0, 0},
                 utc_offset: 3600,
                 std_offset: 0,
                 time_zone: "Europe/Warsaw"
               },
               %DateTime{
                 year: 2000,
                 month: 2,
                 day: 29,
                 zone_abbr: "CET",
                 hour: 23,
                 minute: 10,
                 second: 0,
                 microsecond: {0, 0},
                 utc_offset: 3600,
                 std_offset: 0,
                 time_zone: "Europe/Warsaw"
               }
             )
  end

  test "diff NaiveDateTime" do
    assert [%{a: "u", p: [], t: "2015-01-23 23:50:07"}] =
             Storex.Diff.check(
               NaiveDateTime.from_iso8601!("2015-01-22 12:32:12"),
               NaiveDateTime.from_iso8601!("2015-01-23 23:50:07")
             )
  end

  test "diff Date" do
    assert [%{a: "u", p: [], t: "2016-03-01"}] =
             Storex.Diff.check(
               Date.from_iso8601!("2015-01-23"),
               Date.from_iso8601!("2016-03-01")
             )
  end
end
