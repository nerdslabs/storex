defmodule Storex.Diff do

  @doc """
    a: action
      n - none
      u - update
      d - delete
      i - insert
    f: from
    t: to
    p: path
  """

  # get = (path, object) => path.reduce((o,i)=>o[i], object)

  def check(source, changed) do
    diff(source, changed, [], [])
  end

  defp diff(source, changed, changes, path) when is_list(source) and is_list(changed) do
    source = Enum.with_index(source)
    changed = Enum.with_index(changed)
    compare_list(source, changed, changes, path)
  end

  defp diff(source, changed, changes, path) when is_map(source) and is_map(changed) do
    compare_map(source, changed, changes, path)
  end

  defp diff(source, changed, changes, path) do
    if source === changed do
      changes
    else
      [%{a: "u", t: changed, p: path} | changes]
    end
  end

  defp compare_list([{l, li} | lt], [{r, _ri} | rt], changes, path) do
    changes = diff(l, r, changes, path ++ [li])
    compare_list(lt, rt, changes, path)
  end

  defp compare_list([{_l, li} | lt], [], changes, path) do
    changes = [%{a: "d", p: path ++ [li]} | changes]
    compare_list(lt, [], changes, path)
  end
  defp compare_list([], [{r, ri} | rt], changes, path) do
    changes = [%{a: "i", t: r, p: path ++ [ri]} | changes]
    compare_list([], rt, changes, path)
  end
  defp compare_list([], [], changes, _), do: changes

  defp compare_map(%{__struct__: _} = source, %{__struct__: _} = changed, changes, path) do
    source = Map.from_struct(source)
    changed = Map.from_struct(changed)

    compare_map(source, changed, changes, path)
  end
  defp compare_map(%{__struct__: _} = source, %{} = changed, changes, path) do
    source = Map.from_struct(source)

    compare_map(source, changed, changes, path)
  end
  defp compare_map(%{} = source, %{__struct__: _} = changed, changes, path) do
    changed = Map.from_struct(changed)

    compare_map(source, changed, changes, path)
  end

  defp compare_map(%{} = source, %{} = changed, changes, path) do
    changes = Enum.reduce(source, changes, &compare_map(&1, &2, changed, path, true))
    Enum.reduce(changed, changes, &compare_map(&1, &2, source, path, false))
  end

  defp compare_map({key, value}, acc, changed, path, true) do
    case Map.has_key?(changed, key) do
      false -> [%{a: "d", p: path ++ [key]} | acc]
      true ->
        changed_value = Map.get(changed, key)
        diff(value, changed_value, acc, path ++ [key])
    end
  end

  defp compare_map({key, value}, acc, source, path, false) do
    case Map.has_key?(source, key) do
      false -> [%{a: "i", t: value, p: path ++ [key]} | acc]
      true -> acc
    end
  end
end
