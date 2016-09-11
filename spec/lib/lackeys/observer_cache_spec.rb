# frozen_string_literal: true

require 'spec_helper'
require 'lackeys'

describe Lackeys::ObserverCache, type: :class do
  subject(:cache) { Lackeys::ObserverCache.new(caller) }

  describe '#fetch' do
    subject(:method) { cache.fetch(obs) }
    let(:instance_double) { double }
    let(:calling_object) { double }
    let(:obs) { double }

    before(:each) do
      allow(obs).to receive(:new).and_return(instance_double)
    end

    it { is_expected.to eql(instance_double) }

    it 'returns a new instance of the observer' do
      expect(obs).to receive(:new).once
      method
      method
    end
  end
end
