require 'cases/helper_sqlserver'
require 'models/car'

class ShowplanTestSQLServer < ActiveRecord::TestCase

  fixtures :cars

  # For some reason the default max width truncates values that we are looking for in jruby
  ActiveRecord::ConnectionAdapters::SQLServer::Showplan::PrinterTable.max_column_width = 500 if defined? JRUBY_VERSION

  describe 'Unprepare previously prepared SQL' do

    it 'from simple statement' do
      plan = Car.where(id: 1).explain
      plan.must_include "SELECT [cars].* FROM [cars] WHERE [cars].[id] = 1"
      plan.must_include "Clustered Index Seek", 'make sure we do not showplan the sp_executesql'
    end

    it 'from multiline statement' do
      plan = Car.where("\n id = 1 \n").explain
      plan.must_include "SELECT [cars].* FROM [cars] WHERE (\n id = 1 \n)"
      plan.must_include "Clustered Index Seek", 'make sure we do not showplan the sp_executesql'
    end

    it 'from prepared statement' do
      plan = Car.where(name: ',').limit(1).explain
      plan.must_include " SELECT  [cars].* FROM [cars] WHERE [cars].[name]"
      plan.must_include "TOP EXPRESSION", 'make sure we do not showplan the sp_executesql'
      plan.must_include "Clustered Index Scan", 'make sure we do not showplan the sp_executesql'
    end

    it 'from array condition using index' do
      plan = Car.where(id: [1, 2]).explain
      plan.must_include " SELECT [cars].* FROM [cars] WHERE [cars].[id] IN (1, 2)"
      plan.must_include "Clustered Index Seek", 'make sure we do not showplan the sp_executesql'
    end

    it 'from array condition' do
      plan = Car.where(name: ['honda', 'zyke']).explain
      plan.must_include " SELECT [cars].* FROM [cars] WHERE [cars].[name] IN (N'honda', N'zyke')"
      plan.must_include "Clustered Index Scan", 'make sure we do not showplan the sp_executesql'
    end

  end

  describe 'With SHOWPLAN_TEXT option' do

    it 'use simple table printer' do
      with_showplan_option('SHOWPLAN_TEXT') do
        plan = Car.where(id: 1).explain
        plan.must_include "SELECT [cars].* FROM [cars] WHERE [cars].[id]"
        plan.must_include "Clustered Index Seek", 'make sure we do not showplan the sp_executesql'
      end
    end

  end

  describe 'With SHOWPLAN_XML option' do

    it 'show formatted xml' do
      with_showplan_option('SHOWPLAN_XML') do
        plan = Car.where(id: 1).explain
        plan.must_include 'ShowPlanXML'
      end
    end

  end


  private

  def with_showplan_option(option)
    old_option = ActiveRecord::ConnectionAdapters::SQLServerAdapter.showplan_option
    ActiveRecord::ConnectionAdapters::SQLServerAdapter.showplan_option = option
    yield
  ensure
    ActiveRecord::ConnectionAdapters::SQLServerAdapter.showplan_option = old_option
  end

end
