require "solidus/elastic_product/state"
module Spree::ProductDecorator
  Spree::Product.class_eval do
    # `dependent: :destroy` purposely left off. We don't really want to add a soft
    # delete to the state record (it really inherits the product flag) but the
    # paranoia gem will remove it if we put `dependent: :destroy`
    has_one :elastic_state, class_name: 'Solidus::ElasticProduct::State', inverse_of: :product


    # Customization point for excluding properties from the search index.
    # Can be steered for example via boolean flag on Property.
    # Ex: -> { joins(:property).where(indexable: true) }
    #
    has_many :indexable_product_properties, class_name: 'Spree::ProductProperty'

    # Customization point for excluding taxons from the search index.
    # Can for example be used to index only taxons in chosen Taxonomies
    # via a boolean flag on the Taxonomy table.
    #
    has_many :indexable_classifications, class_name: 'Spree::Classification'

    def indexed_popularity
      line_items.count
    end

    # Very rought implementation. Re-implement in your own code
    # if a more granular approach is required.
    def indexed_price
      Spree::Price.
        joins(:variant).
        where(spree_variants: { product_id: id } ).
        minimum(:amount)
    end

    # Trigger the state reset so that the manager can notice
    # work needs to be done to resync the product's index document
    def reset_index_state
      elastic_state.reset! if elastic_state
    end

    after_commit lambda { reset_index_state },  on: :update
    after_commit lambda { reset_index_state },  on: :destroy

    # Every product should have a state record. This ensures this happens at
    # record creation time. The migration ensures it happens to all existing
    # records.
    def create_index_record
      build_elastic_state product: self unless elastic_state
    end
    before_create :create_index_record
  end
end
