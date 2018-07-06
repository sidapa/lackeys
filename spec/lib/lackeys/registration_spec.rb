# frozen_string_literal: true

require 'spec_helper'
require 'lackeys'

describe Lackeys::Registration, type: :class do
  subject(:registration) { Lackeys::Registration.new(source, dest) }
  let(:source) { Integer }
  let(:dest) { 'String' }

  it 'sets @source instance variable to passed parameter' do
    expect(registration.instance_variable_get(:@source)).to eql(source)
    expect(registration.instance_variable_get(:@dest)).to eql(dest)
    registration
  end

  describe '#add_method' do
    subject(:method) { registration.add_method(method_name, options) }
    let(:method_name) { :foo }
    let(:options) { {} }

    it { should be_nil }

    before(:each) do
      @ex_methods = registration.instance_variable_get(:@exclusive_methods)
      @m_methods = registration.instance_variable_get(:@multi_methods)
    end

    context 'passing in a string as method name' do
      let(:method_name) { 'foo' }
      it 'should convert the name to a symbol' do
        method
        expect(registration.instance_variable_get(:@exclusive_methods))
          .to eql([:foo])
      end
    end

    it { expect { method }.to change { @ex_methods.size }.by 1 }

    context 'allow_multi is set to true' do
      let(:options) { { allow_multi: true } }

      it { expect { method }.not_to change { @ex_methods.size } }
      it { expect { method }.to change { @m_methods.size }.by 1 }
    end

    context 'method already exists' do
      let(:error_msg) { 'foo has already been registered' }

      context 'in @exclusive_methods' do
        before(:each) do
          registration.instance_variable_set(:@exclusive_methods, [:foo])
        end

        it { expect { method }.to raise_error error_msg }
      end

      context 'in @multi_methods' do
        before(:each) do
          registration.instance_variable_set(:@multi_methods, [:foo])
        end

        it { expect { method }.to raise_error error_msg }
      end
    end
  end

  describe '#add_validation' do
    subject(:validation) { registration.add_validation(validation_name) }
    let(:validation_name) { :foo }

    before(:each) do
      @validations = registration.instance_variable_get(:@validations)
    end

    it { should be_nil }

    it { expect { validation }.to change { @validations.size }.by 1 }

    context 'passing in a string as method name' do
      let(:method_name) { 'foo' }
      it 'should convert the name to a symbol' do
        validation
        expect(registration.instance_variable_get(:@validations)).to eql([:foo])
      end
    end

    context 'method already exists' do
      before(:each) do
        registration.instance_variable_set(:@validations, [:foo])
      end
      let(:error) { 'foo has already been registered as validation' }

      it { expect { validation }.to raise_error error }
    end
  end

  describe '#add_callback' do
    subject(:callback) { registration.add_callback(callback_type, method_name) }
    let(:callback_type) { :before_save }
    let(:method_name) { :foo }

    before(:each) do
      @callbacks = registration.instance_variable_get(:@callbacks)
    end

    it { should be_nil }

    it { expect { callback }.to change { @callbacks[callback_type].size }.by 1 }

    context 'passing in a string as method name' do
      let(:method_name) { 'foo' }
      it 'should convert the name to a symbol' do
        callback
        expect(@callbacks[:before_save]).to eql([:foo])
      end
    end

    context 'passing in a string as method name' do
      let(:callback_type) { 'before_save' }
      it 'should convert the name to a symbol' do
        callback
        expect(@callbacks[:before_save]).to eql([:foo])
      end
    end

    context 'callback_type is not supported' do
      let(:callback_type) { :not_supported }

      it { expect { callback }.to raise_error 'not_supported not supported' }
    end

    context 'method already exists' do
      let(:error_msg) { 'foo has already been registered' }
      before(:each) do
        registration.instance_variable_set(:@callbacks, before_save: [:foo])
      end

      it { expect { callback }.to raise_error error_msg }
    end
  end

  describe '#to_h' do
    subject(:method) { new_reg.to_h }
    let(:new_reg) do
      Lackeys::Registration.new(Integer, 'String').tap do |r|
        r.add_method :ex_method
        r.add_method :mul_method, allow_multi: true
        r.add_validation :val
        r.add_callback :before_save, :bs_callback
      end
    end
    let(:output) do
      {
        source: Integer,
        dest: dest,
        exclusive_methods: [:ex_method],
        multi_methods: [:mul_method],
        validations: [:val],
        options: {"Integer#ex_method" => {}, "Integer#mul_method" => {}},
        callbacks: {
          before_save: [:bs_callback],
          after_save: [],
          before_create: [],
          after_create: []
        }
      }
    end

    it { should eql(output) }
  end
end
