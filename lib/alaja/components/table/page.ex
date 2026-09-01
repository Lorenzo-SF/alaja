defmodule Alaja.Components.Table.Page do
  @moduledoc """
  A single page of table data, as returned by a paginated data source.

  Used by `Alaja.Components.Table.print/2` when `:data_fun` is set (see
  its documentation for the full contract).
  """

  @type t :: %__MODULE__{
          headers: list(String.t()) | nil,
          rows: list(list(String.t())),
          page: non_neg_integer(),
          total_pages: pos_integer(),
          total_rows: non_neg_integer()
        }

  defstruct headers: nil,
            rows: [],
            page: 0,
            total_pages: 1,
            total_rows: 0
end
