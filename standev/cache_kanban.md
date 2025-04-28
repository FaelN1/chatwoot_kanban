# Cache do Kanban - Documentação Técnica

## Visão Geral

O sistema de cache do Kanban foi projetado para otimizar o carregamento e atualização de milhares de itens, mantendo a atomicidade e consistência dos dados.

## Estrutura do Cache

### Chaves Utilizadas

```ruby
collection_cache_key = "kanban_items/#{Current.account.id}/funnel_#{funnel_id}/collection"
items_cache_key = "kanban_items/#{Current.account.id}/funnel_#{funnel_id}/items"
item_cache_key = "kanban_items/#{Current.account.id}/item_#{item_id}"
```

### Camadas de Cache

1. **Cache de Collection** (TTL: 1 hora)
   - Armazena apenas IDs dos itens
   - Usado para detectar mudanças na estrutura
   - Invalidado quando ordem/composição muda

2. **Cache de Items** (TTL: 1 hora)
   - Armazena a lista completa serializada
   - Invalidado quando collection muda
   - Reconstruído sob demanda

3. **Cache Individual** (TTL: 1 dia)
   - Cache por item
   - Invalidado apenas quando item é atualizado
   - Contém dados completos do item

## Fluxo de Dados

### Leitura (GET /api/v1/accounts/kanban_items)

```ruby
# 1. Busca IDs frescos do banco
@kanban_items = Current.account.kanban_items
                      .for_funnel(funnel_id)
                      .order_by_position
                      .pluck(:id)

# 2. Verifica mudanças na collection
collection_changed = !Rails.cache.exist?(collection_cache_key) || 
                    Rails.cache.read(collection_cache_key) != @kanban_items

# 3. Se collection mudou, invalida cache de items
if collection_changed
  Rails.cache.write(collection_cache_key, @kanban_items)
  Rails.cache.delete(items_cache_key)
end

# 4. Busca/Constrói lista de items
result = Rails.cache.fetch(items_cache_key, expires_in: 1.hour) do
  @kanban_items.map do |item_id|
    Rails.cache.fetch("kanban_items/#{Current.account.id}/item_#{item_id}", expires_in: 1.day) do
      # Serialização do item
    end
  end
end
```

### Atualização (PUT /api/v1/accounts/kanban_items/:id)

```ruby
# 1. Atualiza item
if @kanban_item.update(kanban_item_params)
  # 2. Invalida apenas cache do item
  Rails.cache.delete("kanban_items/#{Current.account.id}/item_#{@kanban_item.id}")
  # 3. Retorna item atualizado
  render json: serialize_item(@kanban_item)
end
```

## Performance

| Operação | Tempo Médio | Descrição |
|----------|-------------|-----------|
| Primeira Requisição | ~200ms | Cache miss, construção completa |
| Requisições Subsequentes | ~50ms | Cache hit, apenas desserialização |
| Update de Item | ~100ms | Atualização + invalidação pontual |

## Benefícios

1. **Escalabilidade**
   - Suporta milhares de itens
   - Baixo consumo de memória
   - Invalidação granular

2. **Consistência**
   - Cache atômico por item
   - Sem stale data
   - Invalidação precisa

3. **Performance**
   - Menos queries no banco
   - Menos processamento JSON
   - Resposta rápida

## Melhorias Futuras

1. **Redis**
   - Migrar para Redis
   - Melhor performance
   - Mais escalável

2. **Cache Warming**
   - Pré-carregar items populares
   - Reduzir cache misses
   - Melhorar UX

3. **Compression**
   - Comprimir dados em cache
   - Reduzir uso de memória
   - Otimizar network

## Manutenção

### Invalidação Manual

```ruby
# Invalidar item específico
Rails.cache.delete("kanban_items/#{account_id}/item_#{item_id}")

# Invalidar collection inteira
Rails.cache.delete("kanban_items/#{account_id}/funnel_#{funnel_id}/collection")
Rails.cache.delete("kanban_items/#{account_id}/funnel_#{funnel_id}/items")
```

### Monitoramento

Monitore:
- Hit rate do cache
- Tempo de resposta
- Uso de memória
- Cache misses

## Troubleshooting

1. **Cache Inconsistente**
   - Verifique TTLs
   - Invalide collection
   - Verifique locks

2. **Performance Baixa**
   - Monitore cache hits
   - Verifique fragmentação
   - Analise padrões de acesso

3. **Memória Alta**
   - Ajuste TTLs
   - Implemente compression
   - Considere Redis 