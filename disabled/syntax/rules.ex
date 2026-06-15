defmodule Alaja.Syntax.Rules do
  @moduledoc """
  Reglas de syntax highlighting genéricas y configurables.

  En lugar de crear un tokenizer por lenguaje, este módulo permite
  definir reglas de highlighting de forma declarativa.

  ## Uso

      # Definir reglas para Elixir
      rules = %{
        keywords: ~w(def defp defmodule defmacro if case when),
        types: ~w(integer atom list map tuple),
        comments: ~r/#.*/,
        strings: ~r/"[^"]*"/,
        atoms: ~r/:[a-z_]+/
      }

      Syntax.Rules.highlight_line(line, rules, theme)

  ## Estructura de Reglas

      %{
        # Palabras clave (lista de strings)
        keywords: [String.t()],

        # Tipos de datos (lista de strings)
        types: [String.t()],

        # Patrones regex para diferentes elementos
        comments: Regex.t(),
        strings: Regex.t(),
        numbers: Regex.t(),
        atoms: Regex.t(),

        # Colores por tipo (opcional, usa theme por defecto)
        colors: %{
          keywords: :keyword,
          types: :type,
          comments: :comment,
          strings: :string,
          numbers: :number,
          atoms: :atom
        }
      }
  """

  alias Alaja.{Cell, Syntax}

  @type rule_type ::
          :keyword | :type | :comment | :string | :number | :atom | :operator | :function
  @type rules :: %{
          optional(:keywords) => [String.t()],
          optional(:types) => [String.t()],
          optional(:comments) => Regex.t(),
          optional(:strings) => Regex.t(),
          optional(:numbers) => Regex.t(),
          optional(:atoms) => Regex.t(),
          optional(:colors) => %{rule_type => atom()}
        }

  @doc """
  Aplica reglas de highlighting a una línea.

  ## Parámetros

  - `line` - Línea de texto a highlightear
  - `rules` - Mapa de reglas del lenguaje
  - `theme` - Tema de colores (opcional)

  ## Retornos

  Lista de células con colores aplicados
  """
  @spec highlight_line(String.t(), rules(), map()) :: [Cell.t()]
  def highlight_line(line, rules, theme \\ Syntax.default_theme()) do
    tokens = tokenize(line, rules)

    Enum.flat_map(tokens, fn {type, text} ->
      color_key = get_color_for_type(type, rules)
      {:color, color_value} = Map.get(theme, color_key, {:color, "#D4D4D4"})

      String.graphemes(text)
      |> Enum.map(fn char -> Cell.new(char, fg: color_value) end)
    end)
  end

  @doc """
  Tokeniza una línea usando reglas configurables.
  """
  @spec tokenize(String.t(), rules()) :: [{rule_type(), String.t()}]
  def tokenize(line, rules) do
    tokenize_recursive(line, rules, [])
  end

  defp tokenize_recursive("", _rules, acc), do: Enum.reverse(acc)

  defp tokenize_recursive(line, rules, acc) do
    cond do
      match = Regex.run(~r/#.*$/, line) ->
        {match, rest} = String.split_at(line, String.length(hd(match)))
        tokenize_recursive(rest, rules, [{:comment, match} | acc])

      match = Regex.run(~r/"[^"]*"/, line) ->
        {match, rest} = String.split_at(line, String.length(hd(match)))
        tokenize_recursive(rest, rules, [{:string, match} | acc])

      match = Regex.run(~r/'[^']*'/, line) ->
        {match, rest} = String.split_at(line, String.length(hd(match)))
        tokenize_recursive(rest, rules, [{:string, match} | acc])

      match = Regex.run(~r/\b\d+\.?\d*\b/, line) ->
        {match, rest} = String.split_at(line, String.length(hd(match)))
        tokenize_recursive(rest, rules, [{:number, match} | acc])

      match = Regex.run(~r/:[a-zA-Z_][a-zA-Z0-9_]*[?!]?/, line) ->
        {match, rest} = String.split_at(line, String.length(hd(match)))
        tokenize_recursive(rest, rules, [{:atom, match} | acc])

      match = Regex.run(~r/\b[a-zA-Z_][a-zA-Z0-9_]*[?!]?\b/, line) ->
        word = hd(match)
        type = classify_word(word, rules)
        {match, rest} = String.split_at(line, String.length(hd(match)))
        tokenize_recursive(rest, rules, [{type, match} | acc])

      match = Regex.run(~r/[+\-*\/<>=|&!@#$%^~?]+/, line) ->
        {match, rest} = String.split_at(line, String.length(hd(match)))
        tokenize_recursive(rest, rules, [{:operator, match} | acc])

      true ->
        {char, rest} = String.split_at(line, 1)
        tokenize_recursive(rest, rules, [{:text, char} | acc])
    end
  end

  defp classify_word(word, rules) do
    keywords = Map.get(rules, :keywords, [])
    types = Map.get(rules, :types, [])

    cond do
      word in keywords -> :keyword
      word in types -> :type
      Regex.match?(~r/^[A-Z]/, word) -> :type
      true -> :function
    end
  end

  defp get_color_for_type(type, rules) do
    colors =
      Map.get(rules, :colors, %{
        keyword: :keyword,
        type: :type,
        comment: :comment,
        string: :string,
        number: :number,
        atom: :atom,
        operator: :operator,
        function: :function,
        text: :text
      })

    Map.get(colors, type, :text)
  end

  @doc """
  Reglas predefinidas para lenguajes comunes.
  """
  @spec rules_for(atom()) :: rules()

  # ── Elixir ─────────────────────────────────────────────────────────────
  def rules_for(:elixir) do
    %{
      keywords: ~w(def defp defmodule defmacro defimpl defprotocol defstruct
                   defdelegate defoverridable use import require alias
                   if unless case cond with for try rescue catch after
                   receive end do in and or not when fn ->),
      types: ~w(integer atom list map tuple binary pid port reference float
                function arity exception term var any none),
      comments: ~r/#.*/,
      strings: ~r/"[^"]*"/,
      numbers: ~r/\b\d+\.?\d*\b/,
      atoms: ~r/:[a-zA-Z_][a-zA-Z0-9_]*[?!]?/,
      colors: %{
        keyword: :keyword,
        type: :type,
        comment: :comment,
        string: :string,
        number: :number,
        atom: :atom,
        operator: :operator,
        function: :function
      }
    }
  end

  # ── JSON ───────────────────────────────────────────────────────────────
  def rules_for(:json) do
    %{
      keywords: ~w(true false null),
      comments: ~r/\/\/.*$/,
      strings: ~r/"[^"]*"/,
      numbers: ~r/\b\d+\.?\d*\b/,
      colors: %{keyword: :keyword, string: :string, number: :number}
    }
  end

  # ── Markdown ───────────────────────────────────────────────────────────
  def rules_for(:markdown) do
    %{
      keywords: ~w(),
      comments: ~r/<!--.*?-->/s,
      strings: ~r/`[^`]+`/,
      numbers: ~r/\b\d+\b/,
      colors: %{comment: :comment, string: :string}
    }
  end

  # ── Python ─────────────────────────────────────────────────────────────
  def rules_for(:python) do
    %{
      keywords: ~w(
        def class import from as return if elif else while for in
        try except finally with yield raise assert pass break continue
        and or not is lambda None True False global nonlocal del async await
      ),
      types: ~w(int float str list dict tuple set bool bytes object type),
      comments: ~r/#.*/,
      strings: ~r/"[^"]*"|'[^']*'/,
      numbers: ~r/\b\d+\.?\d*\b/,
      colors: %{
        keyword: :keyword,
        type: :type,
        comment: :comment,
        string: :string,
        number: :number,
        function: :function
      }
    }
  end

  # ── TypeScript / JavaScript ────────────────────────────────────────────
  def rules_for(:typescript) do
    %{
      keywords: ~w(
        function const let var class extends implements interface type enum
        export default import from as return if else switch case break
        continue try catch finally throw new delete typeof instanceof
        async await yield of in for while do void null undefined true false
        public private protected readonly static abstract declare
      ),
      types: ~w(string number boolean Array Object Map Set Promise Date Error
                Record Partial Required Pick Omit Exclude Extract),
      comments: ~r/\/\/.*$|\/\*.*?\*\//s,
      strings: ~r/"[^"]*"|'[^']*'|`[^`]*`/,
      numbers: ~r/\b\d+\.?\d*\b/,
      colors: %{
        keyword: :keyword,
        type: :type,
        comment: :comment,
        string: :string,
        number: :number,
        function: :function
      }
    }
  end

  def rules_for(:javascript), do: rules_for(:typescript)
  def rules_for(:tsx), do: rules_for(:typescript)

  # ── Rust ───────────────────────────────────────────────────────────────
  def rules_for(:rust) do
    %{
      keywords: ~w(
        fn let mut const static struct enum trait impl use mod pub crate self
        super where for in while loop break continue if else match return
        move ref dyn as async await unsafe extern type
      ),
      types: ~w(i8 i16 i32 i64 i128 u8 u16 u32 u64 u128 f32 f64 bool char str
                String Vec Option Result HashMap Box Arc Rc Cell RefCell
                usize isize),
      comments: ~r/\/\/.*$|\/\*.*?\*\//s,
      strings: ~r/"[^"]*"/,
      numbers: ~r/\b\d+\.?\d*\b/,
      colors: %{
        keyword: :keyword,
        type: :type,
        comment: :comment,
        string: :string,
        number: :number,
        function: :function
      }
    }
  end

  # ── Go ────────────────────────────────────────────────────────────────
  def rules_for(:go) do
    %{
      keywords: ~w(
        func var const type struct interface map chan go select defer
        if else switch case fallthrough for range break continue return
        import package nil true false goto
      ),
      types: ~w(int int8 int16 int32 int64 uint uint8 uint16 uint32 uint64
                float32 float64 complex64 complex128 byte rune string bool
                error any),
      comments: ~r/\/\/.*$|\/\*.*?\*\//s,
      strings: ~r/"[^"]*"|`[^`]*`/,
      numbers: ~r/\b\d+\.?\d*\b/,
      colors: %{
        keyword: :keyword,
        type: :type,
        comment: :comment,
        string: :string,
        number: :number,
        function: :function
      }
    }
  end

  # ── Java ───────────────────────────────────────────────────────────────
  def rules_for(:java) do
    %{
      keywords: ~w(
        class interface extends implements enum record public private protected
        static final abstract synchronized volatile transient native strictfp
        if else switch case default break continue return for while do
        try catch finally throw throws new instanceof this super import package
        void null true false var
      ),
      types: ~w(int long float double boolean char byte short String Object
                List Map Set Collection Optional Stream Integer),
      comments: ~r/\/\/.*$|\/\*.*?\*\//s,
      strings: ~r/"[^"]*"/,
      numbers: ~r/\b\d+\.?\d*\b/,
      colors: %{
        keyword: :keyword,
        type: :type,
        comment: :comment,
        string: :string,
        number: :number,
        function: :function
      }
    }
  end

  # ── Kotlin ─────────────────────────────────────────────────────────────
  def rules_for(:kotlin) do
    %{
      keywords: ~w(
        fun val var class interface object enum data sealed open override
        abstract final internal private protected public companion init
        constructor if else when try catch finally throw return break
        continue for while do in as is null true false suspend
        import package typealias
      ),
      types: ~w(Int Long Float Double Boolean Char Byte Short String List Set
                Map Array Unit Nothing Any),
      comments: ~r/\/\/.*$|\/\*.*?\*\//s,
      strings: ~r/"[^"]*"/,
      numbers: ~r/\b\d+\.?\d*\b/,
      colors: %{
        keyword: :keyword,
        type: :type,
        comment: :comment,
        string: :string,
        number: :number,
        function: :function
      }
    }
  end

  # ── C# ─────────────────────────────────────────────────────────────────
  def rules_for(:csharp) do
    %{
      keywords: ~w(
        class struct interface enum record delegate event namespace using
        public private protected internal static readonly const virtual
        override abstract sealed async await var if else switch case
        break continue return for foreach while do try catch finally
        throw new null true false in out ref get set value where select
        typeof sizeof nameof
      ),
      types: ~w(int long float double decimal bool char byte short string
                object void dynamic var Task List Dictionary IEnumerable),
      comments: ~r/\/\/.*$|\/\*.*?\*\//s,
      strings: ~r/"[^"]*"/,
      numbers: ~r/\b\d+\.?\d*\b/,
      colors: %{
        keyword: :keyword,
        type: :type,
        comment: :comment,
        string: :string,
        number: :number,
        function: :function
      }
    }
  end

  # ── C / C++ ───────────────────────────────────────────────────────────
  def rules_for(:c) do
    %{
      keywords: ~w(
        if else switch case break continue return for while do goto
        typedef struct enum union const static volatile extern register
        auto signed unsigned sizeof void NULL
      ),
      types: ~w(int long float double char short void size_t uint8_t int32_t),
      comments: ~r/\/\/.*$|\/\*.*?\*\//s,
      strings: ~r/"[^"]*"/,
      numbers: ~r/\b\d+\.?\d*\b/,
      colors: %{
        keyword: :keyword,
        type: :type,
        comment: :comment,
        string: :string,
        number: :number,
        function: :function
      }
    }
  end

  def rules_for(:cpp) do
    %{
      keywords: rules_for(:c).keywords ++ ~w(
        class namespace template typename virtual override new delete
        public private protected mutable explicit constexpr noexcept
        decltype nullptr auto using operator try catch throw
      ),
      types: rules_for(:c).types ++ ~w(bool string vector map shared_ptr unique_ptr),
      comments: ~r/\/\/.*$|\/\*.*?\*\//s,
      strings: ~r/"[^"]*"/,
      numbers: ~r/\b\d+\.?\d*\b/,
      colors: %{
        keyword: :keyword,
        type: :type,
        comment: :comment,
        string: :string,
        number: :number,
        function: :function
      }
    }
  end

  # ── PHP ────────────────────────────────────────────────────────────────
  def rules_for(:php) do
    %{
      keywords: ~w(
        function class interface trait extends implements namespace use
        public private protected static final abstract const var if else
        elseif switch case break continue return for foreach while do
        try catch finally throw new instanceof global yield from as
        null true false array list
      ),
      types: ~w(int float string bool array object callable void mixed
                null never true false),
      comments: ~r/\/\/.*$|#.*$|\/\*.*?\*\//s,
      strings: ~r/"[^"]*"|'[^']*'/,
      numbers: ~r/\b\d+\.?\d*\b/,
      colors: %{
        keyword: :keyword,
        type: :type,
        comment: :comment,
        string: :string,
        number: :number,
        function: :function
      }
    }
  end

  # ── Ruby ───────────────────────────────────────────────────────────────
  def rules_for(:ruby) do
    %{
      keywords: ~w(
        def class module end if else elsif unless case when while until
        for in do break next return yield rescue ensure raise begin
        require include extend private protected public attr_accessor
        attr_reader attr_writer self super nil true false
      ),
      types: ~w(String Integer Float Array Hash Symbol Proc Lambda Range),
      comments: ~r/#.*/,
      strings: ~r/"[^"]*"|'[^']*'/,
      numbers: ~r/\b\d+\.?\d*\b/,
      atoms: ~r/:[a-zA-Z_][a-zA-Z0-9_]*[?!]?/,
      colors: %{
        keyword: :keyword,
        type: :type,
        comment: :comment,
        string: :string,
        number: :number,
        atom: :atom,
        function: :function
      }
    }
  end

  # ── Swift ──────────────────────────────────────────────────────────────
  def rules_for(:swift) do
    %{
      keywords: ~w(
        func class struct enum protocol extension let var if else guard
        switch case break continue return for in while repeat do try
        catch throw throws async await import public private internal
        fileprivate open final static override mutating required optional
        convenience init deinit self super nil true false
      ),
      types: ~w(Int Float Double Bool String Character Array Dictionary Set
                Optional Result Void Error Any),
      comments: ~r/\/\/.*$|\/\*.*?\*\//s,
      strings: ~r/"[^"]*"/,
      numbers: ~r/\b\d+\.?\d*\b/,
      colors: %{
        keyword: :keyword,
        type: :type,
        comment: :comment,
        string: :string,
        number: :number,
        function: :function
      }
    }
  end

  # ── Dart ───────────────────────────────────────────────────────────────
  def rules_for(:dart) do
    %{
      keywords: ~w(
        class mixin extension enum typedef abstract static final const
        void if else switch case break continue return for while do
        try catch finally throw rethrow import export library part
        as is new in var dynamic null true false async await yield
        factory super this
      ),
      types: ~w(int double String bool List Map Set Stream Future
                void dynamic Object),
      comments: ~r/\/\/.*$|\/\*.*?\*\//s,
      strings: ~r/"[^"]*"|'[^']*'/,
      numbers: ~r/\b\d+\.?\d*\b/,
      colors: %{
        keyword: :keyword,
        type: :type,
        comment: :comment,
        string: :string,
        number: :number,
        function: :function
      }
    }
  end

  # ── Scala ──────────────────────────────────────────────────────────────
  def rules_for(:scala) do
    %{
      keywords: ~w(
        val var def class object trait extends with case sealed abstract
        override implicit lazy final private protected if else match
        try catch finally for yield while do return throw import
        package type this super null true false new
      ),
      types: ~w(Int Long Float Double Boolean Char Byte Short String
                List Map Set Option Either Try Future),
      comments: ~r/\/\/.*$|\/\*.*?\*\//s,
      strings: ~r/"[^"]*"/,
      numbers: ~r/\b\d+\.?\d*\b/,
      colors: %{
        keyword: :keyword,
        type: :type,
        comment: :comment,
        string: :string,
        number: :number,
        function: :function
      }
    }
  end

  # ── Lua ────────────────────────────────────────────────────────────────
  def rules_for(:lua) do
    %{
      keywords: ~w(
        function local if then else elseif for in while do repeat until
        return break end nil true false and or not goto
      ),
      types: ~w(number string boolean table function thread nil),
      comments: ~r/--.*$|--\[\[.*?\]\]/s,
      strings: ~r/"[^"]*"|'[^']*'|\[\[.*?\]\]/s,
      numbers: ~r/\b\d+\.?\d*\b/,
      colors: %{
        keyword: :keyword,
        type: :type,
        comment: :comment,
        string: :string,
        number: :number,
        function: :function
      }
    }
  end

  # ── Bash / Shell ───────────────────────────────────────────────────────
  def rules_for(:bash) do
    %{
      keywords: ~w(
        if then elif else fi for while do done in case esac function
        return break continue exit export readonly local declare
        eval exec source echo printf
      ),
      types: ~w(),
      comments: ~r/#.*/,
      strings: ~r/"[^"]*"|'[^']*'/,
      numbers: ~r/\b\d+\.?\d*\b/,
      colors: %{
        keyword: :keyword,
        comment: :comment,
        string: :string,
        number: :number,
        function: :function
      }
    }
  end

  def rules_for(:shell), do: rules_for(:bash)

  # ── R ──────────────────────────────────────────────────────────────────
  def rules_for(:r) do
    %{
      keywords: ~w(
        function if else for while repeat break next return in
        library require source NULL NA TRUE FALSE Inf NaN
      ),
      types: ~w(numeric integer character logical factor vector list
                matrix array data.frame),
      comments: ~r/#.*/,
      strings: ~r/"[^"]*"|'[^']*'/,
      numbers: ~r/\b\d+\.?\d*\b/,
      colors: %{
        keyword: :keyword,
        type: :type,
        comment: :comment,
        string: :string,
        number: :number,
        function: :function
      }
    }
  end

  # ── Haskell ────────────────────────────────────────────────────────────
  def rules_for(:haskell) do
    %{
      keywords: ~w(
        module where import qualified let in case of if then else
        data type newtype class instance deriving do return
        infixl infixr infix
      ),
      types: ~w(Int Integer Float Double Char Bool String Maybe Either IO
                Map Set Vector),
      comments: ~r/--.*$|\{-.*?-\}/s,
      strings: ~r/"[^"]*"/,
      numbers: ~r/\b\d+\.?\d*\b/,
      colors: %{
        keyword: :keyword,
        type: :type,
        comment: :comment,
        string: :string,
        number: :number,
        function: :function
      }
    }
  end

  # ── Clojure ────────────────────────────────────────────────────────────
  def rules_for(:clojure) do
    %{
      keywords: ~w(
        def defn defmacro fn let if when cond case loop recur
        try catch finally throw ns require use import refer
        new nil true false
      ),
      types: ~w(),
      comments: ~r/;.*/,
      strings: ~r/"[^"]*"/,
      numbers: ~r/\b\d+\.?\d*\b/,
      atoms: ~r/:[a-zA-Z_][a-zA-Z0-9_\-\.]*/,
      colors: %{
        keyword: :keyword,
        comment: :comment,
        string: :string,
        number: :number,
        atom: :atom
      }
    }
  end

  # ── Zig ────────────────────────────────────────────────────────────────
  def rules_for(:zig) do
    %{
      keywords: ~w(
        fn struct enum union const var if else switch while for
        break continue return try catch defer errdefer comptime
        test export pub usingnamespace anytype void
      ),
      types: ~w(i8 i16 i32 i64 u8 u16 u32 u64 f16 f32 f64 bool void
                noreturn type anyerror comptime_int),
      comments: ~r/\/\/.*$/,
      strings: ~r/"[^"]*"/,
      numbers: ~r/\b\d+\.?\d*\b/,
      colors: %{
        keyword: :keyword,
        type: :type,
        comment: :comment,
        string: :string,
        number: :number,
        function: :function
      }
    }
  end

  # ── Nim ────────────────────────────────────────────────────────────────
  def rules_for(:nim) do
    %{
      keywords: ~w(
        proc func method iterator converter template macro
        if elif else case of when while for break continue
        return yield try except finally raise import export
        from include var let const type object tuple enum
        ref ptr distinct static
      ),
      types: ~w(int int8 int16 int32 int64 uint uint8 uint16 uint32 uint64
                float float32 float64 bool char string seq set array
                Table cstring pointer),
      comments: ~r/#.*$/,
      strings: ~r/"[^"]*"/,
      numbers: ~r/\b\d+\.?\d*\b/,
      colors: %{
        keyword: :keyword,
        type: :type,
        comment: :comment,
        string: :string,
        number: :number,
        function: :function
      }
    }
  end

  # ── OCaml ──────────────────────────────────────────────────────────────
  def rules_for(:ocaml) do
    %{
      keywords: ~w(
        let in module struct sig end fun function match with
        if then else try with exception raise type of as
        when and or not rec mutable private val external
        include open inherit
      ),
      types: ~w(int float char string bool list array option unit
                ref exn),
      comments: ~r/\(\*.*?\*\)/s,
      strings: ~r/"[^"]*"/,
      numbers: ~r/\b\d+\.?\d*\b/,
      colors: %{
        keyword: :keyword,
        type: :type,
        comment: :comment,
        string: :string,
        number: :number,
        function: :function
      }
    }
  end

  # ── Erlang ─────────────────────────────────────────────────────────────
  def rules_for(:erlang) do
    %{
      keywords: ~w(
        module export import compile define record if case
        of when catch after try receive end fun let
      ),
      types: ~w(integer float atom list tuple map binary pid port reference),
      comments: ~r/%.*$/,
      strings: ~r/"[^"]*"/,
      numbers: ~r/\b\d+\.?\d*\b/,
      atoms: ~r/'[a-zA-Z_][a-zA-Z0-9_]*'/,
      colors: %{
        keyword: :keyword,
        type: :type,
        comment: :comment,
        string: :string,
        number: :number,
        atom: :atom,
        function: :function
      }
    }
  end

  # ── SQL ────────────────────────────────────────────────────────────────
  def rules_for(:sql) do
    %{
      keywords: ~w(
        SELECT FROM WHERE INSERT INTO VALUES UPDATE SET DELETE
        CREATE TABLE INDEX VIEW DROP ALTER ADD COLUMN CONSTRAINT
        PRIMARY KEY FOREIGN REFERENCES NOT NULL DEFAULT UNIQUE
        CHECK JOIN LEFT RIGHT INNER OUTER ON AND OR AS DISTINCT
        GROUP BY ORDER ASC DESC HAVING LIMIT OFFSET UNION ALL
        EXISTS CASE WHEN THEN ELSE END BEGIN COMMIT ROLLBACK
      ),
      types: ~w(INTEGER VARCHAR TEXT BOOLEAN DATE TIMESTAMP FLOAT
                DECIMAL BIGINT UUID JSON ARRAY),
      comments: ~r/--.*$/,
      strings: ~r/'[^']*'/,
      numbers: ~r/\b\d+\.?\d*\b/,
      colors: %{
        keyword: :keyword,
        type: :type,
        comment: :comment,
        string: :string,
        number: :number,
        function: :function
      }
    }
  end

  # ── CSS ────────────────────────────────────────────────────────────────
  def rules_for(:css) do
    %{
      keywords: ~w(),
      types: ~w(),
      comments: ~r/\/\*.*?\*\//s,
      strings: ~r/"[^"]*"|'[^']*'/,
      numbers: ~r/\b\d+\.?\d*\b/,
      colors: %{comment: :comment, string: :string, number: :number}
    }
  end

  # ── HTML ───────────────────────────────────────────────────────────────
  def rules_for(:html) do
    %{
      keywords: ~w(),
      types: ~w(),
      comments: ~r/<!--.*?-->/s,
      strings: ~r/"[^"]*"|'[^']*'/,
      numbers: ~r/\b\d+\b/,
      colors: %{comment: :comment, string: :string, number: :number}
    }
  end

  # ── Dockerfile ─────────────────────────────────────────────────────────
  def rules_for(:dockerfile) do
    %{
      keywords: ~w(FROM RUN CMD EXPOSE ENV COPY ADD WORKDIR ENTRYPOINT
                   VOLUME USER ARG LABEL ONBUILD STOPSIGNAL HEALTHCHECK
                   SHELL MAINTAINER),
      types: ~w(),
      comments: ~r/#.*/,
      strings: ~r/"[^"]*"|'[^']*'/,
      numbers: ~r/\b\d+\.?\d*\b/,
      colors: %{keyword: :keyword, comment: :comment, string: :string, number: :number}
    }
  end

  # ── TOML ───────────────────────────────────────────────────────────────
  def rules_for(:toml) do
    %{
      keywords: ~w(true false),
      types: ~w(),
      comments: ~r/#.*/,
      strings: ~r/"[^"]*"|'[^']*'/,
      numbers: ~r/\b\d+\.?\d*\b/,
      colors: %{keyword: :keyword, comment: :comment, string: :string, number: :number}
    }
  end

  # ── YAML ───────────────────────────────────────────────────────────────
  def rules_for(:yaml) do
    %{
      keywords: ~w(true false null yes no on off),
      types: ~w(),
      comments: ~r/#.*/,
      strings: ~r/"[^"]*"|'[^']*'/,
      numbers: ~r/\b\d+\.?\d*\b/,
      colors: %{keyword: :keyword, comment: :comment, string: :string, number: :number}
    }
  end

  # ── HCL / Terraform ───────────────────────────────────────────────────
  def rules_for(:hcl) do
    %{
      keywords: ~w(resource data module variable output provider terraform
                   locals),
      types: ~w(string number bool list map set object tuple any),
      comments: ~r/#.*$/,
      strings: ~r/"[^"]*"/,
      numbers: ~r/\b\d+\.?\d*\b/,
      colors: %{
        keyword: :keyword,
        type: :type,
        comment: :comment,
        string: :string,
        number: :number
      }
    }
  end

  # ── Fallback ───────────────────────────────────────────────────────────
  def rules_for(_), do: rules_for(:elixir)
end
