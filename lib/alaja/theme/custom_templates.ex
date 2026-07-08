defmodule Alaja.Theme.CustomTemplates do
  @moduledoc """
  Extra theme templates that ship with Alaja on top of those provided by Pote.

  These are defined as `%Pote.Theme.Theme{}` structs and installed alongside
  Pote's built-in templates when `alaja config init` runs.
  """

  @catppuccin %Pote.Theme.Theme{
    name: "catppuccin",
    description: "Catppuccin Mocha — warm pastel on deep brown-black",
    colors: %{
      "primary" => {203, 166, 247},
      "secondary" => {148, 226, 213},
      "ternary" => {250, 179, 135},
      "quaternary" => {245, 194, 231},
      "no_color" => {205, 214, 244},
      "background" => {30, 30, 46},
      "success" => {166, 227, 161},
      "warning" => {249, 226, 175},
      "error" => {243, 139, 168},
      "info" => {137, 180, 250},
      "menu" => {48, 50, 66},
      "alert" => {250, 179, 135},
      "critical" => {243, 139, 168},
      "debug" => {108, 112, 134},
      "happy" => {245, 194, 231},
      "sad" => {137, 180, 250},
      "gradient_1" => {203, 166, 247},
      "gradient_2" => {137, 180, 250},
      "gradient_3" => {148, 226, 213},
      "gradient_4" => {166, 227, 161},
      "gradient_5" => {249, 226, 175},
      "gradient_6" => {250, 179, 135}
    }
  }

  @solarized %Pote.Theme.Theme{
    name: "solarized-dark",
    description: "Solarized Dark — precision palette with balanced luminance",
    colors: %{
      "primary" => {38, 139, 210},
      "secondary" => {42, 161, 152},
      "ternary" => {203, 75, 22},
      "quaternary" => {108, 113, 196},
      "no_color" => {147, 161, 161},
      "background" => {7, 54, 66},
      "success" => {133, 153, 0},
      "warning" => {181, 137, 0},
      "error" => {220, 50, 47},
      "info" => {38, 139, 210},
      "menu" => {0, 43, 54},
      "alert" => {203, 75, 22},
      "critical" => {220, 50, 47},
      "debug" => {88, 110, 117},
      "happy" => {108, 113, 196},
      "sad" => {38, 139, 210},
      "gradient_1" => {38, 139, 210},
      "gradient_2" => {42, 161, 152},
      "gradient_3" => {133, 153, 0},
      "gradient_4" => {181, 137, 0},
      "gradient_5" => {203, 75, 22},
      "gradient_6" => {220, 50, 47}
    }
  }

  @gruvbox %Pote.Theme.Theme{
    name: "gruvbox-dark",
    description: "Gruvbox Dark — retro groove, warm earthy tones",
    colors: %{
      "primary" => {254, 128, 25},
      "secondary" => {142, 192, 124},
      "ternary" => {250, 189, 47},
      "quaternary" => {211, 134, 155},
      "no_color" => {235, 219, 178},
      "background" => {40, 40, 40},
      "success" => {184, 187, 38},
      "warning" => {250, 189, 47},
      "error" => {251, 73, 52},
      "info" => {131, 165, 152},
      "menu" => {50, 48, 47},
      "alert" => {254, 128, 25},
      "critical" => {251, 73, 52},
      "debug" => {146, 131, 116},
      "happy" => {211, 134, 155},
      "sad" => {131, 165, 152},
      "gradient_1" => {254, 128, 25},
      "gradient_2" => {250, 189, 47},
      "gradient_3" => {184, 187, 38},
      "gradient_4" => {142, 192, 124},
      "gradient_5" => {131, 165, 152},
      "gradient_6" => {211, 134, 155}
    }
  }

  @tokyo_night %Pote.Theme.Theme{
    name: "tokyo-night",
    description: "Tokyo Night — stormy night, deep blues and neon accents",
    colors: %{
      "primary" => {122, 162, 247},
      "secondary" => {115, 218, 202},
      "ternary" => {255, 158, 100},
      "quaternary" => {187, 154, 247},
      "no_color" => {192, 202, 245},
      "background" => {26, 27, 46},
      "success" => {158, 206, 106},
      "warning" => {224, 175, 104},
      "error" => {247, 118, 142},
      "info" => {122, 162, 247},
      "menu" => {36, 38, 58},
      "alert" => {255, 158, 100},
      "critical" => {247, 118, 142},
      "debug" => {86, 95, 137},
      "happy" => {187, 154, 247},
      "sad" => {122, 162, 247},
      "gradient_1" => {122, 162, 247},
      "gradient_2" => {115, 218, 202},
      "gradient_3" => {158, 206, 106},
      "gradient_4" => {224, 175, 104},
      "gradient_5" => {255, 158, 100},
      "gradient_6" => {247, 118, 142}
    }
  }

  @everforest %Pote.Theme.Theme{
    name: "everforest-dark",
    description: "Everforest Dark — nature-inspired, soft muted greens",
    colors: %{
      "primary" => {167, 192, 128},
      "secondary" => {127, 187, 179},
      "ternary" => {230, 152, 117},
      "quaternary" => {214, 153, 182},
      "no_color" => {211, 198, 170},
      "background" => {45, 53, 59},
      "success" => {131, 192, 146},
      "warning" => {219, 188, 127},
      "error" => {230, 126, 128},
      "info" => {127, 187, 179},
      "menu" => {52, 61, 67},
      "alert" => {230, 152, 117},
      "critical" => {230, 126, 128},
      "debug" => {146, 144, 129},
      "happy" => {214, 153, 182},
      "sad" => {127, 187, 179},
      "gradient_1" => {167, 192, 128},
      "gradient_2" => {131, 192, 146},
      "gradient_3" => {127, 187, 179},
      "gradient_4" => {219, 188, 127},
      "gradient_5" => {230, 152, 117},
      "gradient_6" => {230, 126, 128}
    }
  }

  @rose_pine %Pote.Theme.Theme{
    name: "rose-pine",
    description: "Rose Pine — soft rose & pine, earthy elegance",
    colors: %{
      "primary" => {235, 188, 186},
      "secondary" => {156, 207, 216},
      "ternary" => {246, 193, 119},
      "quaternary" => {196, 167, 231},
      "no_color" => {224, 222, 244},
      "background" => {25, 23, 36},
      "success" => {49, 116, 143},
      "warning" => {246, 193, 119},
      "error" => {235, 111, 146},
      "info" => {156, 207, 216},
      "menu" => {31, 29, 46},
      "alert" => {246, 193, 119},
      "critical" => {235, 111, 146},
      "debug" => {110, 106, 134},
      "happy" => {235, 188, 186},
      "sad" => {49, 116, 143},
      "gradient_1" => {196, 167, 231},
      "gradient_2" => {156, 207, 216},
      "gradient_3" => {49, 116, 143},
      "gradient_4" => {235, 188, 186},
      "gradient_5" => {246, 193, 119},
      "gradient_6" => {235, 111, 146}
    }
  }

  @ayu %Pote.Theme.Theme{
    name: "ayu-dark",
    description: "Ayu Dark — warm dusk, soft contrast comfort palette",
    colors: %{
      "primary" => {255, 180, 84},
      "secondary" => {115, 208, 255},
      "ternary" => {186, 230, 126},
      "quaternary" => {212, 191, 255},
      "no_color" => {203, 204, 198},
      "background" => {13, 16, 23},
      "success" => {186, 230, 126},
      "warning" => {255, 143, 64},
      "error" => {255, 96, 96},
      "info" => {115, 208, 255},
      "menu" => {18, 22, 30},
      "alert" => {255, 143, 64},
      "critical" => {255, 96, 96},
      "debug" => {92, 95, 94},
      "happy" => {212, 191, 255},
      "sad" => {115, 208, 255},
      "gradient_1" => {255, 180, 84},
      "gradient_2" => {242, 158, 116},
      "gradient_3" => {186, 230, 126},
      "gradient_4" => {115, 208, 255},
      "gradient_5" => {212, 191, 255},
      "gradient_6" => {255, 143, 64}
    }
  }

  @synthwave %Pote.Theme.Theme{
    name: "synthwave",
    description: "Synthwave — retrowave neon, deep purple with hot pink & cyan",
    colors: %{
      "primary" => {255, 126, 219},
      "secondary" => {0, 255, 255},
      "ternary" => {255, 202, 133},
      "quaternary" => {162, 119, 255},
      "no_color" => {224, 224, 224},
      "background" => {36, 27, 64},
      "success" => {72, 217, 184},
      "warning" => {255, 202, 133},
      "error" => {249, 126, 114},
      "info" => {130, 226, 255},
      "menu" => {46, 35, 80},
      "alert" => {255, 202, 133},
      "critical" => {249, 126, 114},
      "debug" => {120, 100, 160},
      "happy" => {255, 126, 219},
      "sad" => {162, 119, 255},
      "gradient_1" => {255, 126, 219},
      "gradient_2" => {162, 119, 255},
      "gradient_3" => {130, 226, 255},
      "gradient_4" => {0, 255, 255},
      "gradient_5" => {72, 217, 184},
      "gradient_6" => {255, 202, 133}
    }
  }

  @aurora %Pote.Theme.Theme{
    name: "aurora",
    description: "Aurora — northern lights, deep night with ice blue & emerald",
    colors: %{
      "primary" => {160, 196, 255},
      "secondary" => {112, 225, 181},
      "ternary" => {251, 191, 36},
      "quaternary" => {192, 132, 252},
      "no_color" => {224, 230, 240},
      "background" => {13, 19, 33},
      "success" => {112, 225, 181},
      "warning" => {251, 191, 36},
      "error" => {251, 113, 133},
      "info" => {34, 211, 238},
      "menu" => {20, 28, 48},
      "alert" => {251, 191, 36},
      "critical" => {251, 113, 133},
      "debug" => {120, 130, 150},
      "happy" => {244, 114, 182},
      "sad" => {160, 196, 255},
      "gradient_1" => {160, 196, 255},
      "gradient_2" => {34, 211, 238},
      "gradient_3" => {112, 225, 181},
      "gradient_4" => {192, 132, 252},
      "gradient_5" => {244, 114, 182},
      "gradient_6" => {251, 191, 36}
    }
  }

  @material_ocean %Pote.Theme.Theme{
    name: "material-ocean",
    description: "Material Ocean — deep blue-ocean, Material Design inspired",
    colors: %{
      "primary" => {130, 170, 255},
      "secondary" => {137, 221, 255},
      "ternary" => {247, 140, 108},
      "quaternary" => {177, 166, 240},
      "no_color" => {192, 202, 245},
      "background" => {15, 17, 26},
      "success" => {195, 232, 141},
      "warning" => {255, 203, 107},
      "error" => {240, 113, 120},
      "info" => {130, 170, 255},
      "menu" => {22, 25, 38},
      "alert" => {247, 140, 108},
      "critical" => {240, 113, 120},
      "debug" => {92, 100, 120},
      "happy" => {177, 166, 240},
      "sad" => {130, 170, 255},
      "gradient_1" => {130, 170, 255},
      "gradient_2" => {137, 221, 255},
      "gradient_3" => {195, 232, 141},
      "gradient_4" => {255, 203, 107},
      "gradient_5" => {247, 140, 108},
      "gradient_6" => {240, 113, 120}
    }
  }

  @outrun %Pote.Theme.Theme{
    name: "outrun",
    description: "Outrun — 80s neon, deep purple with hot pink & cyan bursts",
    colors: %{
      "primary" => {255, 100, 128},
      "secondary" => {0, 229, 255},
      "ternary" => {255, 179, 0},
      "quaternary" => {179, 136, 255},
      "no_color" => {224, 224, 255},
      "background" => {26, 11, 46},
      "success" => {118, 255, 3},
      "warning" => {255, 179, 0},
      "error" => {255, 100, 128},
      "info" => {0, 229, 255},
      "menu" => {38, 20, 62},
      "alert" => {255, 179, 0},
      "critical" => {255, 100, 128},
      "debug" => {100, 80, 140},
      "happy" => {255, 110, 180},
      "sad" => {179, 136, 255},
      "gradient_1" => {255, 100, 128},
      "gradient_2" => {179, 136, 255},
      "gradient_3" => {0, 229, 255},
      "gradient_4" => {118, 255, 3},
      "gradient_5" => {255, 179, 0},
      "gradient_6" => {255, 110, 180}
    }
  }

  @kanagawa %Pote.Theme.Theme{
    name: "kanagawa",
    description: "Kanagawa — Japanese ink wash, sumi black with warm paper tones",
    colors: %{
      "primary" => {255, 150, 102},
      "secondary" => {100, 180, 110},
      "ternary" => {220, 190, 70},
      "quaternary" => {160, 140, 210},
      "no_color" => {220, 215, 186},
      "background" => {31, 31, 40},
      "success" => {100, 180, 110},
      "warning" => {220, 190, 70},
      "error" => {230, 70, 90},
      "info" => {130, 180, 230},
      "menu" => {54, 54, 70},
      "alert" => {255, 150, 102},
      "critical" => {230, 70, 90},
      "debug" => {84, 84, 106},
      "happy" => {160, 140, 210},
      "sad" => {130, 180, 230},
      "gradient_1" => {130, 180, 230},
      "gradient_2" => {100, 180, 110},
      "gradient_3" => {220, 190, 70},
      "gradient_4" => {255, 150, 102},
      "gradient_5" => {230, 70, 90},
      "gradient_6" => {160, 140, 210}
    }
  }

  @doc false
  @spec all :: [Pote.Theme.Theme.t()]
  def all do
    [
      @catppuccin,
      @solarized,
      @gruvbox,
      @tokyo_night,
      @everforest,
      @rose_pine,
      @ayu,
      @synthwave,
      @aurora,
      @material_ocean,
      @outrun,
      @kanagawa
    ]
  end
end
