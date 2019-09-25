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
    assert [%{a: "i", p: [2], t: 3}, %{a: "d", p: [1, 1]}, %{a: "u", p: [0], t: 2}] = Storex.Diff.check([1, [1, 2]], [2, [1], 3])
  end

  test "diff map" do
    assert [%{a: "i", p: [:c], t: "c"}, %{a: "d", p: [:b]}, %{a: "u", p: [:a], t: 1}] = Storex.Diff.check(%{a: "a", b: "b"}, %{a: 1, c: "c"})
  end

  test "diff struct" do
    assert [%{a: "u", p: [:name], t: "B"}, %{a: "u", p: [:age], t: 10}] = Storex.Diff.check(%Struct{name: "A"}, %Struct{name: "B", age: 10})
  end

  test "diff DateTime" do
    assert [%{a: "u", p: [], t: "2019-09-25 10:35:00.628127Z"}] = Storex.Diff.check(~U[2019-09-25 10:33:59.628127Z], ~U[2019-09-25 10:35:00.628127Z])
  end

  test "diff NaiveDateTime" do
    assert [%{a: "u", p: [], t: "2019-08-23 17:28:59"}] = Storex.Diff.check(~N[2019-08-09 17:28:59], ~N[2019-08-23 17:28:59])
  end
end
