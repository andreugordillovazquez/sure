class Provider::Openai::AutoCategorizer
  include Provider::Openai::Concerns::UsageRecorder

  # JSON response format modes for custom providers
  # - "strict": Use strict JSON schema (requires full OpenAI API compatibility)
  # - "json_object": Use json_object response format (broader compatibility)
  # - "none": No response format constraint (maximum compatibility with local LLMs)
  JSON_MODE_STRICT = "strict"
  JSON_MODE_OBJECT = "json_object"
  JSON_MODE_NONE = "none"
  JSON_MODE_AUTO = "auto"

  # Threshold for auto mode: if more than this percentage returns null, retry with none mode
  AUTO_MODE_NULL_THRESHOLD = 0.5

  # CUSTOM: Descriptions for each category to disambiguate similar ones.
  # Keys must match exactly the category names in Sure.
  CATEGORY_DESCRIPTIONS = {
    "Ahorro e inversiones"   => "Transferencias a cuentas de ahorro o fondos de inversión propios",
    "Intereses"              => "Intereses cobrados de cuentas remuneradas o depósitos bancarios",
    "Aportaciones a inversiones" => "Compras de acciones, ETFs, fondos o crypto",
    "Pagos de préstamos"     => "Cuotas de préstamos o hipotecas",
    "Supermercado"           => "Compras en supermercados: Mercadona, Lidl, Carrefour, Dia, Alcampo, Consum, Bonpreu, Esclat",
    "Comida y bebida"        => "Restaurantes, bares y locales donde se come o cena. NO supermercados, NO cafeterías",
    "Café"                   => "Cafeterías, pastelerías y locales donde solo se toma café o desayuno",
    "Transporte"             => "Transporte público: metro, bus, tren, Renfe, FGC, taxi, Uber, Cabify, Bolt",
    "Gasolina"               => "Gasolineras: Repsol, BP, Cepsa, Galp, Shell, Petrocat",
    "Aparcamiento"           => "Parkings, zonas azules, OTA, parquímetros",
    "Compras"                => "Tiendas de ropa, electrónica, Amazon, Zara, H&M, El Corte Inglés, Shein, AliExpress",
    "Ropa"                   => "Tiendas especializadas en ropa y calzado: Zara, Mango, Pull&Bear, Decathlon (ropa)",
    "Entretenimiento"        => "Cine, conciertos, espectáculos, Netflix (si no es suscripción recurrente)",
    "Suscripciones"          => "Pagos recurrentes mensuales/anuales: Netflix, Spotify, Amazon Prime, software, gimnasio",
    "Deportes y fitness"     => "Gimnasios, equipamiento deportivo, actividades deportivas",
    "Viajes"                 => "Vuelos, hoteles, Airbnb, alquiler de coches, actividades turísticas",
    "Seguros"                => "Primas de seguro: coche, hogar, vida, salud",
    "Salud"                  => "Farmacia, médico, dentista, óptica, clínicas",
    "Cuidado personal"       => "Peluquería, barbería, spa, cosmética, perfumería",
    "Transferencias"         => "Transferencias entre cuentas propias o envíos de dinero (Bizum, wire transfer)",
    "Hipoteca / Alquiler"    => "Pago mensual de alquiler o hipoteca de vivienda",
    "Mejora del hogar"       => "Bricolaje, muebles, electrodomésticos, fontanería, IKEA, Leroy Merlin",
    "Utilidades"             => "Facturas de electricidad, gas, agua, internet, móvil",
    "Servicios"              => "Servicios profesionales: gestoría, abogado, notaría, limpieza del hogar",
    "Salario"                => "Nómina o ingreso de empresa empleadora",
    "Comisiones"             => "Comisiones bancarias, gastos de mantenimiento de cuenta o tarjeta",
    "Impuestos"              => "Pagos a la AEAT, Hacienda, ayuntamiento (IBI, IVTM), multas de tráfico",
    "Regalos y donaciones"   => "Regalos a otras personas, donaciones a ONGs",
    "Software y herramientas" => "Licencias de software, dominios, hosting, herramientas digitales profesionales",
    "Supermercado"           => "Mercadona, Lidl, Carrefour, Dia, Alcampo, Consum, Bonpreu, Esclat"
  }.freeze

  # CUSTOM: Few-shot examples with real Spanish merchants to guide the model.
  SPANISH_FEW_SHOT_EXAMPLES = [
    { description: "MERCADONA 1234 GIRONA",        amount: 45.20,  classification: "expense", category: "Supermercado" },
    { description: "LIDL SUPRA ESP 00032",          amount: 28.50,  classification: "expense", category: "Supermercado" },
    { description: "REPSOL ES 00234 AUTOPISTA",     amount: 65.00,  classification: "expense", category: "Gasolina" },
    { description: "BP ESTACION SERVICIO",          amount: 55.30,  classification: "expense", category: "Gasolina" },
    { description: "NETFLIX.COM",                   amount: 15.99,  classification: "expense", category: "Suscripciones" },
    { description: "SPOTIFY AB",                    amount: 9.99,   classification: "expense", category: "Suscripciones" },
    { description: "AMAZON PRIME",                  amount: 4.99,   classification: "expense", category: "Suscripciones" },
    { description: "AMAZON.ES MARKETPLACE",         amount: 32.00,  classification: "expense", category: "Compras" },
    { description: "ZARA.COM ONLINE",               amount: 49.95,  classification: "expense", category: "Ropa" },
    { description: "FARMACIA CENTRAL GIRONA",       amount: 12.40,  classification: "expense", category: "Salud" },
    { description: "RENFE OPERADORA",               amount: 24.00,  classification: "expense", category: "Transporte" },
    { description: "CABIFY SPAIN SL",               amount: 8.50,   classification: "expense", category: "Transporte" },
    { description: "PARKING SABA ZONA FRANCA",      amount: 5.00,   classification: "expense", category: "Aparcamiento" },
    { description: "IKEA BADALONA",                 amount: 120.00, classification: "expense", category: "Mejora del hogar" },
    { description: "LEROY MERLIN",                  amount: 45.00,  classification: "expense", category: "Mejora del hogar" },
    { description: "ENDESA ENERGIA",                amount: 78.00,  classification: "expense", category: "Utilidades" },
    { description: "VODAFONE ESPANA SAU",           amount: 35.00,  classification: "expense", category: "Utilidades" },
    { description: "DECATHLON GIRONA",              amount: 29.99,  classification: "expense", category: "Deportes y fitness" },
    { description: "EL CORTE INGLES SA",            amount: 55.00,  classification: "expense", category: "Compras" },
    { description: "COMPRA BIZUM 34612345678",      amount: 20.00,  classification: "expense", category: "Transferencias" },
    { description: "NOMINA EMPRESA SL OCTUBRE",     amount: 2500.0, classification: "income",  category: "Salario" },
    { description: "INTERESES CUENTA REMUNERADA",   amount: 1.23,   classification: "income",  category: "Intereses" },
    { description: "CAFE BAR EL MERCAT",            amount: 3.50,   classification: "expense", category: "Café" },
    { description: "RESTAURANTE LA BRASA GIRONA",   amount: 32.00,  classification: "expense", category: "Comida y bebida" },
    { description: "GLOVO SPAIN",                   amount: 18.50,  classification: "expense", category: "Comida y bebida" },
    { description: "JUST EAT SPAIN",               amount: 22.00,  classification: "expense", category: "Comida y bebida" },
    { description: "MUTUA MADRILENA SEGUROS",       amount: 65.00,  classification: "expense", category: "Seguros" },
    { description: "HACIENDA AEAT PAGO 100",        amount: 200.00, classification: "expense", category: "Impuestos" },
    { description: "REVOLUT*CRYPTO PURCHASE",       amount: 50.00,  classification: "expense", category: "Aportaciones a inversiones" },
    { description: "TRANSFERENCIA A CUENTA AHORRO", amount: 500.00, classification: "expense", category: "Ahorro e inversiones" }
  ].freeze

  attr_reader :client, :model, :transactions, :user_categories, :custom_provider, :langfuse_trace, :family, :json_mode

  def initialize(client, model: "", transactions: [], user_categories: [], custom_provider: false, langfuse_trace: nil, family: nil, json_mode: nil)
    @client = client
    @model = model
    @transactions = transactions
    @user_categories = user_categories
    @custom_provider = custom_provider
    @langfuse_trace = langfuse_trace
    @family = family
    @json_mode = json_mode || default_json_mode
  end

  VALID_JSON_MODES = [ JSON_MODE_STRICT, JSON_MODE_OBJECT, JSON_MODE_NONE, JSON_MODE_AUTO ].freeze

  def default_json_mode
    env_mode = ENV["LLM_JSON_MODE"]
    return env_mode if env_mode.present? && VALID_JSON_MODES.include?(env_mode)

    setting_mode = Setting.openai_json_mode
    return setting_mode if setting_mode.present? && VALID_JSON_MODES.include?(setting_mode)

    JSON_MODE_AUTO
  end

  def auto_categorize
    if custom_provider
      auto_categorize_openai_generic
    else
      auto_categorize_openai_native
    end
  end

  def instructions
    if custom_provider
      simple_instructions
    else
      detailed_instructions
    end
  end

  # CUSTOM: Enriched instructions for custom/OpenRouter providers.
  # Adds Spanish context, category descriptions, few-shot examples, and
  # disambiguation rules for categories that are commonly confused.
  def simple_instructions
    categories_with_descriptions = user_categories.map do |c|
      desc = CATEGORY_DESCRIPTIONS[c[:name]]
      if desc
        "- #{c[:name]}: #{desc}"
      else
        "- #{c[:name]}"
      end
    end.join("\n")

    few_shot_lines = SPANISH_FEW_SHOT_EXAMPLES
      .select { |ex| user_categories.any? { |c| c[:name] == ex[:category] } }
      .map { |ex| "  \"#{ex[:description]}\" (#{ex[:classification]}, #{ex[:amount]}€) → #{ex[:category]}" }
      .join("\n")

    <<~INSTRUCTIONS.strip_heredoc
      You are a personal finance categorization assistant for a user based in Spain (Catalonia).
      Transactions are in Spanish or Catalan. Merchant names follow Spanish bank formatting conventions.

      AVAILABLE CATEGORIES (with descriptions to help you decide):
      #{categories_with_descriptions}

      EXAMPLES OF CORRECT CATEGORIZATIONS:
      #{few_shot_lines}

      CRITICAL RULES:
      1. Match transaction_id exactly from the input — never invent IDs
      2. Use the EXACT category name from the list above (case-sensitive)
      3. Prefer the MOST SPECIFIC subcategory when you are confident
      4. Return "null" if you are less than 60% confident — false negatives are better than false positives
      5. Return "null" for generic/unrecognizable entries (e.g., "COMPRA TPV", "PAGO DOMICILIADO", "TRANSFERENCIA EMITIDA")
      6. Expense transactions → expense categories; income transactions → income categories

      SPANISH-SPECIFIC DISAMBIGUATION:
      - Supermercado vs Comida y bebida: supermarkets (Mercadona, Lidl…) → Supermercado; restaurants/bars → Comida y bebida
      - Café vs Comida y bebida: coffee shops / breakfast spots → Café; full meals → Comida y bebida
      - Compras vs Ropa: clothing-only stores → Ropa; general retail / Amazon → Compras
      - Transferencias: Bizum payments and bank transfers between own accounts → Transferencias
      - Suscripciones: recurring monthly/annual digital services → Suscripciones
      - Gasolina: gas stations only → Gasolina; highway tolls → Transporte
      - "CARGO CUOTA" or "MANTENIMIENTO CUENTA" → Comisiones

      Output ONLY valid JSON, no markdown, no explanation:
      {"categorizations": [{"transaction_id": "...", "category_name": "..."}]}
    INSTRUCTIONS
  end

  # Detailed instructions for larger models like GPT-4 (native OpenAI path)
  def detailed_instructions
    <<~INSTRUCTIONS.strip_heredoc
      You are an assistant to a consumer personal finance app.  You will be provided a list
      of the user's transactions and a list of the user's categories.  Your job is to auto-categorize
      each transaction.

      Closely follow ALL the rules below while auto-categorizing:

      - Return 1 result per transaction
      - Correlate each transaction by ID (transaction_id)
      - Attempt to match the most specific category possible (i.e. subcategory over parent category)
      - Any category can be used for any transaction regardless of whether the transaction is income or expense
      - If you don't know the category, return "null"
        - You should always favor "null" over false positives
        - Be slightly pessimistic.  Only match a category if you're 60%+ confident it is the correct one.
      - Each transaction has varying metadata that can be used to determine the category
        - Note: "hint" comes from 3rd party aggregators and typically represents a category name that
          may or may not match any of the user-supplied categories
    INSTRUCTIONS
  end

  private

    def auto_categorize_openai_native
      span = langfuse_trace&.span(name: "auto_categorize_api_call", input: {
        model: model.presence || Provider::Openai::DEFAULT_MODEL,
        transactions: transactions,
        user_categories: user_categories
      })

      response = client.responses.create(parameters: {
        model: model.presence || Provider::Openai::DEFAULT_MODEL,
        input: [ { role: "developer", content: developer_message } ],
        text: {
          format: {
            type: "json_schema",
            name: "auto_categorize_personal_finance_transactions",
            strict: true,
            schema: json_schema
          }
        },
        instructions: instructions
      })
      Rails.logger.info("Tokens used to auto-categorize transactions: #{response.dig("usage", "total_tokens")}")

      categorizations = extract_categorizations_native(response)
      result = build_response(categorizations)

      record_usage(
        model.presence || Provider::Openai::DEFAULT_MODEL,
        response.dig("usage"),
        operation: "auto_categorize",
        metadata: {
          transaction_count: transactions.size,
          category_count: user_categories.size
        }
      )

      span&.end(output: result.map(&:to_h), usage: response.dig("usage"))
      result
    rescue => e
      span&.end(output: { error: e.message }, level: "ERROR")
      raise
    end

    def auto_categorize_openai_generic
      if json_mode == JSON_MODE_AUTO
        auto_categorize_with_auto_mode
      else
        auto_categorize_with_mode(json_mode)
      end
    rescue Faraday::BadRequestError => e
      if json_mode == JSON_MODE_STRICT || json_mode == JSON_MODE_AUTO
        Rails.logger.warn("Strict JSON mode failed, falling back to none mode: #{e.message}")
        auto_categorize_with_mode(JSON_MODE_NONE)
      else
        raise
      end
    end

    def auto_categorize_with_auto_mode
      result = auto_categorize_with_mode(JSON_MODE_STRICT)

      null_count = result.count { |r| r.category_name.nil? || r.category_name == "null" }
      missing_count = transactions.size - result.size
      failed_count = null_count + missing_count
      failed_ratio = transactions.size > 0 ? failed_count.to_f / transactions.size : 0.0

      if failed_ratio > AUTO_MODE_NULL_THRESHOLD
        Rails.logger.info("Auto mode: #{(failed_ratio * 100).round}% failed (#{null_count} nulls, #{missing_count} missing) in strict mode, retrying with none mode")
        auto_categorize_with_mode(JSON_MODE_NONE)
      else
        result
      end
    end

    def auto_categorize_with_mode(mode)
      span = langfuse_trace&.span(name: "auto_categorize_api_call", input: {
        model: model.presence || Provider::Openai::DEFAULT_MODEL,
        transactions: transactions,
        user_categories: user_categories,
        json_mode: mode
      })

      params = {
        model: model.presence || Provider::Openai::DEFAULT_MODEL,
        messages: [
          { role: "system", content: instructions },
          { role: "user", content: developer_message_for_generic }
        ]
      }

      case mode
      when JSON_MODE_STRICT
        params[:response_format] = {
          type: "json_schema",
          json_schema: {
            name: "auto_categorize_personal_finance_transactions",
            strict: true,
            schema: json_schema
          }
        }
      when JSON_MODE_OBJECT
        params[:response_format] = { type: "json_object" }
      end

      response = client.chat(parameters: params)

      Rails.logger.info("Tokens used to auto-categorize transactions: #{response.dig("usage", "total_tokens")} (json_mode: #{mode})")

      categorizations = extract_categorizations_generic(response)
      result = build_response(categorizations)

      record_usage(
        model.presence || Provider::Openai::DEFAULT_MODEL,
        response.dig("usage"),
        operation: "auto_categorize",
        metadata: {
          transaction_count: transactions.size,
          category_count: user_categories.size,
          json_mode: mode
        }
      )

      span&.end(output: result.map(&:to_h), usage: response.dig("usage"))
      result
    rescue => e
      span&.end(output: { error: e.message }, level: "ERROR")
      raise
    end

    AutoCategorization = Provider::LlmConcept::AutoCategorization

    def build_response(categorizations)
      categorizations.map do |categorization|
        AutoCategorization.new(
          transaction_id: categorization.dig("transaction_id"),
          category_name: normalize_category_name(categorization.dig("category_name")),
        )
      end
    end

    def normalize_category_name(category_name)
      normalized = category_name.to_s.strip
      return nil if normalized.empty? || normalized == "null" || normalized.downcase == "null"

      # Try exact match first
      exact_match = user_categories.find { |c| c[:name] == normalized }
      return exact_match[:name] if exact_match

      # Try case-insensitive match
      case_insensitive_match = user_categories.find { |c| c[:name].to_s.downcase == normalized.downcase }
      return case_insensitive_match[:name] if case_insensitive_match

      # Try fuzzy match
      fuzzy_match = find_fuzzy_category_match(normalized)
      return fuzzy_match if fuzzy_match

      normalized
    end

    def find_fuzzy_category_match(category_name)
      input_str = category_name.to_s
      normalized_input = input_str.downcase.gsub(/[^a-z0-9áéíóúüñ]/, "")

      user_categories.each do |cat|
        cat_name_str = cat[:name].to_s
        normalized_cat = cat_name_str.downcase.gsub(/[^a-z0-9áéíóúüñ]/, "")

        return cat[:name] if normalized_input.include?(normalized_cat) || normalized_cat.include?(normalized_input)
        return cat[:name] if fuzzy_name_match?(input_str, cat_name_str)
      end

      nil
    end

    # CUSTOM: Spanish-aware fuzzy matching for common category name variations.
    def fuzzy_name_match?(input, category)
      variations = {
        # Spanish
        "gasolina"              => [ "gas & fuel", "combustible", "carburante", "gasoil" ],
        "supermercado"          => [ "supermercados", "grocery", "groceries", "alimentacion", "alimentación" ],
        "comida y bebida"       => [ "restaurantes", "restaurants", "dining", "food & drink", "food and drink" ],
        "café"                  => [ "cafe", "coffee", "coffee shops", "cafeteria", "cafetería" ],
        "transporte"            => [ "transport", "transportation", "taxi", "rideshare" ],
        "suscripciones"         => [ "subscriptions", "streaming", "streaming services" ],
        "deportes y fitness"    => [ "gym", "fitness", "deporte", "gimnasio" ],
        "viajes"                => [ "travel", "flights", "hotels", "vuelos", "hoteles" ],
        "mejora del hogar"      => [ "home improvement", "hogar", "bricolaje" ],
        "cuidado personal"      => [ "personal care", "belleza", "beauty" ],
        "regalos y donaciones"  => [ "gifts", "donations", "donaciones", "regalos" ],
        "utilidades"            => [ "utilities", "bills", "facturas" ],
        "compras"               => [ "shopping", "retail", "tiendas" ],
        "transferencias"        => [ "transfers", "bizum", "wire transfer" ],
        "pagos de préstamos"    => [ "loan payment", "hipoteca", "prestamo", "préstamo" ],
        "ahorro e inversiones"  => [ "savings", "investment", "investing", "ahorro" ],
        "impuestos"             => [ "taxes", "tax", "hacienda", "aeat" ],
        "comisiones"            => [ "fees", "bank fees", "commission", "cargo" ],
        "salario"               => [ "salary", "payroll", "nomina", "nómina", "income" ],
        "intereses"             => [ "interest", "interest income", "rendimientos" ]
      }

      input_lower = input.to_s.downcase
      category_lower = category.to_s.downcase

      variations.each do |key, synonyms|
        all = [ key ] + synonyms
        if all.include?(input_lower) && all.include?(category_lower)
          return true
        end
      end

      false
    end

    def extract_categorizations_native(response)
      message_output = response["output"]&.find { |o| o["type"] == "message" }
      raw = message_output&.dig("content", 0, "text")

      raise Provider::Openai::Error, "No message content found in response" if raw.nil?

      JSON.parse(raw).dig("categorizations")
    rescue JSON::ParserError => e
      raise Provider::Openai::Error, "Invalid JSON in native categorization: #{e.message}"
    end

    def extract_categorizations_generic(response)
      raw = response.dig("choices", 0, "message", "content")
      parsed = parse_json_flexibly(raw)

      categorizations = parsed.dig("categorizations") ||
                        parsed.dig("results") ||
                        (parsed.is_a?(Array) ? parsed : nil)

      raise Provider::Openai::Error, "Could not find categorizations in response" if categorizations.nil?

      categorizations.map do |cat|
        {
          "transaction_id" => cat["transaction_id"] || cat["id"] || cat["txn_id"],
          "category_name" => cat["category_name"] || cat["category"] || cat["name"]
        }
      end
    end

    def parse_json_flexibly(raw)
      return {} if raw.blank?

      cleaned = strip_thinking_tags(raw)

      JSON.parse(cleaned)
    rescue JSON::ParserError
      if cleaned =~ /```(?:json)?\s*(\{[\s\S]*?\})\s*```/m
        matches = cleaned.scan(/```(?:json)?\s*(\{[\s\S]*?\})\s*```/m).flatten
        matches.reverse_each do |match|
          begin
            return JSON.parse(match)
          rescue JSON::ParserError
            next
          end
        end
      end

      if cleaned =~ /```(?:json)?\s*(\{[\s\S]*\})\s*$/m
        begin
          return JSON.parse($1)
        rescue JSON::ParserError
        end
      end

      if cleaned =~ /(\{"categorizations"\s*:\s*\[[\s\S]*\]\s*\})/m
        matches = cleaned.scan(/(\{"categorizations"\s*:\s*\[[\s\S]*?\]\s*\})/m).flatten
        matches.reverse_each do |match|
          begin
            return JSON.parse(match)
          rescue JSON::ParserError
            next
          end
        end
        begin
          return JSON.parse($1)
        rescue JSON::ParserError
        end
      end

      if cleaned =~ /(\{[\s\S]*\})/m
        begin
          return JSON.parse($1)
        rescue JSON::ParserError
        end
      end

      raise Provider::Openai::Error, "Could not parse JSON from response: #{raw.truncate(200)}"
    end

    def strip_thinking_tags(raw)
      if raw.include?("<think>")
        if raw =~ /<\/think>\s*([\s\S]*)/m
          after_thinking = $1.strip
          return after_thinking if after_thinking.present?
        end
        if raw =~ /<think>([\s\S]*)/m
          return $1
        end
      end
      raw
    end

    def json_schema
      {
        type: "object",
        properties: {
          categorizations: {
            type: "array",
            description: "An array of auto-categorizations for each transaction",
            items: {
              type: "object",
              properties: {
                transaction_id: {
                  type: "string",
                  description: "The internal ID of the original transaction",
                  enum: transactions.map { |t| t[:id] }
                },
                category_name: {
                  type: "string",
                  description: "The matched category name of the transaction, or null if no match",
                  enum: [ *user_categories.map { |c| c[:name] }, "null" ]
                }
              },
              required: [ "transaction_id", "category_name" ],
              additionalProperties: false
            }
          }
        },
        required: [ "categorizations" ],
        additionalProperties: false
      }
    end

    def developer_message
      <<~MESSAGE.strip_heredoc
        Here are the user's available categories in JSON format:

        ```json
        #{user_categories.to_json}
        ```

        Use the available categories to auto-categorize the following transactions:

        ```json
        #{transactions.to_json}
        ```
      MESSAGE
    end

    # CUSTOM: Concise message for generic/custom providers.
    # Category list is already in the system prompt with descriptions,
    # so here we just send the raw transactions.
    def developer_message_for_generic
      <<~MESSAGE.strip_heredoc
        Categorize the following transactions using the categories and rules from your instructions.

        TRANSACTIONS:
        #{format_transactions_simply}

        Remember: output ONLY valid JSON, no markdown, no explanation:
        {"categorizations": [{"transaction_id": "...", "category_name": "..."}]}
      MESSAGE
    end

    def format_transactions_simply
      transactions.map do |t|
        description = t[:description].presence || t[:merchant].presence || ""
        "- ID: #{t[:id]}, Amount: #{t[:amount]}€, Type: #{t[:classification]}, Description: \"#{description}\""
      end.join("\n")
    end
end
