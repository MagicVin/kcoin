module HistoryHelpers

  include UserAppHelpers
  include FabricHelpers
  include GithubHelpers

  def get_project_list_history(user_id)
    project_list = User[user_id].projects
    args = project_list.map {|x| x[:symbol] + '_' + x[:eth_account]}
    result = batch_query_history(args)
    result.each do |project_history|
      handle_history(project_history)
    end

    result
  end

  def get_history_by_project(symbol, account)
    list = query_history(symbol, account)
    handle_history(list)
    list
  end

  def get_kcoin_history(owner)
    history = query_history(settings.kcoin_symbol, owner)
    handle_history(history)
    history
  end

  def handle_history(history)
    symbol = nil
    history['History'].to_enum.with_index.reverse_each do |item, index|
      item[:Date] = DateTime.parse(item['Timestamp']).strftime('%m.%d')
      item[:Year] = DateTime.parse(item['Timestamp']).strftime('%y')
      item[:Time] = DateTime.parse(item['Timestamp']).strftime('%y.%m.%d')

      item[:ChangeNum] = if index > 0
                           item['Supply'] - ((history['History'] || {})[index - 1] || {})['Supply']
                         else
                           item['Supply']
                         end
      symbol = item['TokenSymbol'] if symbol.nil?
      event = GithubEvent.first(transaction_id: item['TxId'])
      item[:EventName] = event.nil? ? 'no github event' : event[:github_event]
    end

    project = Project.first(symbol: symbol)
    if project.nil?
      history[:ProjectName] = nil
      history[:Img] = nil
    else
      history[:ProjectName] = project[:name]
      history[:Img] = project[:img]
    end
    history[:TokenSymbol] = symbol
  end

  def group_history(history)
    result = []
    array = history[:History].group_by {|h| h[:TokenSymbol]}.values
    array.each do |item|
      record = {}
      record[:KCoin] = (item[0] || {})[:KCoin]
      record[:TokenSymbol] = (item[0] || {})[:TokenSymbol]
      record[:History] = item
      project = Project.first(symbol: record[:TokenSymbol])
      next if project.nil?
      record[:ProjectName] = project[:name]
      record[:Img] = project[:img]
      result << record
    end
    result
  end
end