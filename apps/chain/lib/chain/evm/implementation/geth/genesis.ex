defmodule Chain.EVM.Implementation.Geth.Genesis do
  @moduledoc """
  Genesis generator for `geth` chain.

  Module is responsible for generating new `genesis.json`

  Here are set of settings for new genesis:
   - `chain_id` - chain Id (Default: `999`)
   - `difficulty` - calc difficulty (Default: `1`)
   - `gas_limit` - gas limit for chain (Default: `6_000_000`)
   - `accounts` - List of accounts

  ## Accounts
  First of all before creating genesis accounts should be created using `Chain.EVM.Geth.create_account/1`.
  You could provide list of accounts in 2 different ways.
   
  **Address as string**
  Just binary string with account Ex: `"172536bfde649d20eaf4ac7a3eab742b9a6cc373"`
  It will set account balance to `500000`

  **Address with balance as tuple**
  Provide tuple with `{address, balance}`
  Example: `{"172536bfde649d20eaf4ac7a3eab742b9a6cc373", 100000}`

  Of course you could combine definitions.
  """

  # Default balance for account
  @balance "100000000000000000000"

  @type t :: %__MODULE__{
          chain_id: non_neg_integer(),
          difficulty: non_neg_integer(),
          gas_limit: non_neg_integer(),
          accounts: [binary | {binary, non_neg_integer()}]
        }

  defstruct chain_id: 999, difficulty: 1, gas_limit: 6_000_000, accounts: []

  @doc """
  Write new `genesis.json` file into provided path.
  Path should be to directory where `genesis.json` file will be created.

  If no directory under `path` exist. system will try to create this dir.

  Example: 
  ```elixir
  iex> alias Chain.EVM.Geth.Genesis
  Chain.EVM.Geth.Genesis
  iex> Genesis.write(%Genesis{accounts: [{"172536bfde649d20eaf4ac7a3eab742b9a6cc373", 100000}]}, "/home/user/geth_data")
  :ok
  ```
  """
  @spec write(Chain.EVM.Geth.Genesis.t(), binary) :: :ok | {:error, term}
  def write(%__MODULE__{} = genesis, path) do
    # create dir if not exist
    unless File.dir?(path) do
      File.mkdir_p!(path)
    end

    # Generate binary content for file
    content =
      genesis
      |> to_json()
      |> Poison.encode!()

    # Writing to file
    path
    |> Path.join("genesis.json")
    |> File.write(content, [:binary])
  end

  defp to_json(%__MODULE__{accounts: accounts} = genesis) do
    %{
      config: %{
        chainId: Map.get(genesis, :chain_id, 999),
        homesteadBlock: 0,
        eip155Block: 0,
        eip158Block: 0
      },
      difficulty: Map.get(genesis, :difficulty, 1) |> to_string(),
      gasLimit: Map.get(genesis, :gas_limit, 2_100_000) |> to_string(),
      alloc: build_alloc(accounts)
    }
  end

  defp build_alloc([]), do: %{}

  defp build_alloc(accounts) do
    accounts
    |> Enum.map(&build_account/1)
    |> Enum.into(%{})
  end

  defp build_account({<<"0x", address::binary>>, balance}),
    do: {address, %{balance: to_string(balance)}}

  defp build_account({address, balance}), do: {address, %{balance: to_string(balance)}}
  defp build_account(<<"0x", address::binary>>), do: {address, %{balance: @balance}}
  defp build_account(address) when is_binary(address), do: {address, %{balance: @balance}}
end
