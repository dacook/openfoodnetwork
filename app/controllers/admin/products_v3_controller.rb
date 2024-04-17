# frozen_string_literal: true

module Admin
  class ProductsV3Controller < Spree::Admin::BaseController
    before_action :init_filters_params
    before_action :init_pagination_params

    def index
      fetch_products

      respond_to do |format|
        format.html do
          render "index", locals: { producers:, categories:, flash: }
        end
        format.turbo_stream do |format|
          # We shouldn't need to specify an action (replace), we should be able to just render.
          # render turbo_stream: turbo_stream.replace("products-content", partial: "content",
          #   locals: { products: @products, pagy: @pagy, search_term: @search_term,
          #                                  producer_options: producers, producer_id: @producer_id,
          #                                  category_options: categories, category_id: @category_id,
          #                                  flashes: flash })

          render partial: "content", layout: false, formats: :html,
                 locals: { products: @products, pagy: @pagy, search_term: @search_term,
                           producer_options: producers, producer_id: @producer_id,
                           category_options: categories, category_id: @category_id,
                           flashes: flash }
        end
      end
    end

    def bulk_update
      product_set = product_set_from_params

      product_set.collection.each { |p| authorize! :update, p }
      @products = product_set.collection # use instance variable mainly for testing

      if product_set.save
        flash[:success] = I18n.t('admin.products_v3.bulk_update.success')

        # respond_to do |format|
          # format.turbo_stream do
          #   # index.module.js:1642 Successful form submissions must redirect
          #   ## actually, most "replace" actions don't have to be a turbo_steam, just a plain <turbo-frame>
            # render turbo_stream: turbo_stream.replace("products-content", partial: "content",
            #   locals: { products: @products, pagy: @pagy, search_term: @search_term,
            #                                  producer_options: producers, producer_id: @producer_id,
            #                                  category_options: categories, category_id: @category_id,
            #                                  flashes: flash })
          # end

          # why isn't it turbo_frame?? hmm. just redirect to index anyways.
         #  format.turbo_stream do |format|
         #    redirect_to [:index,
         #                 { page: @page, per_page: @per_page, search_term: @search_term,
         #                   producer_id: @producer_id, category_id: @category_id, format: :turbo_stream }]
         #  end

         # format.html do
            redirect_to [:index,
                         { page: @page, per_page: @per_page, search_term: @search_term,
                           producer_id: @producer_id, category_id: @category_id}]
          # end
        # end

      elsif product_set.errors.present?
        @error_counts = { saved: product_set.saved_count, invalid: product_set.invalid.count }

        respond_to do |format|
          format.turbo_stream do
            # render status: :unprocessable_entity, turbo_stream: turbo_stream.replace("products-content", partial: "content",
            #   locals: { products: @products, pagy: @pagy, search_term: @search_term,
            #                                  producer_options: producers, producer_id: @producer_id,
            #                                  category_options: categories, category_id: @category_id,
            #                                  flashes: flash })


            # Render content with bare minimum html. it doesn't like that. hmm, are we really within a turbo_frame then?
            render "_content", status: :unprocessable_entity, formats: :html, layout: "layouts/turbo_rails/frame",
                   locals: { products: @products, pagy: @pagy, search_term: @search_term,
                             producer_options: producers, producer_id: @producer_id,
                             category_options: categories, category_id: @category_id,
                             flashes: flash }
          end

         format.html do
            render "index", status: :unprocessable_entity, locals: { producers:, categories:, flash: }
          end
        end
      end
    end

    def index_url(params)
      "/admin/products?#{params.to_query}" # todo: fix routing so this can be automaticly generated
    end

    private

    def init_filters_params
      # params comes from the form
      # _params comes from the url
      # priority is given to params from the form (if present) over url params
      @search_term = params[:search_term] || params[:_search_term]
      @producer_id = params[:producer_id] || params[:_producer_id]
      @category_id = params[:category_id] || params[:_category_id]
    end

    def init_pagination_params
      # prority is given to element dataset (if present) over url params
      @page = params[:page].presence || 1
      @per_page = params[:per_page].presence || 15
    end

    def producers
      producers = OpenFoodNetwork::Permissions.new(spree_current_user)
        .managed_product_enterprises.is_primary_producer.by_name
      producers.map { |p| [p.name, p.id] }
    end

    def categories
      Spree::Taxon.order(:name).map { |c| [c.name, c.id] }
    end

    def fetch_products
      product_query = OpenFoodNetwork::Permissions.new(spree_current_user)
        .editable_products.merge(product_scope).ransack(ransack_query).result
      @pagy, @products = pagy(product_query.order(:name), items: @per_page, page: @page,
                                                          size: [1, 2, 2, 1])
    end

    def product_scope
      user = spree_current_user
      scope = if user.has_spree_role?("admin") || user.enterprises.present?
                Spree::Product
              else
                Spree::Product.active
              end

      scope.includes(product_query_includes).distinct
    end

    def ransack_query
      query = {}
      query.merge!(supplier_id_in: @producer_id) if @producer_id.present?
      if @search_term.present?
        query.merge!(Spree::Variant::SEARCH_KEY => @search_term)
      end
      query.merge!(variants_primary_taxon_id_in: @category_id) if @category_id.present?
      query
    end

    # Optimise by pre-loading required columns
    def product_query_includes
      # TODO: add other fields used in columns? (eg supplier: [:name])
      [
        # variants: [
        #   :default_price,
        #   :stock_locations,
        #   :stock_items,
        #   :variant_overrides
        # ]
      ]
    end

    # Similar to spree/admin/products_controller
    def product_set_from_params
      # Form field names:
      #   '[products][0][id]' (hidden field)
      #   '[products][0][name]'
      #   '[products][0][variants_attributes][0][id]' (hidden field)
      #   '[products][0][variants_attributes][0][display_name]'
      #
      # Resulting in params:
      #     "products" => {
      #       "0" =>  {
      #         "id" => "123"
      #         "name" => "Pommes",
      #         "variants_attributes" => {
      #           "0" => {
      #           "id" => "1234",
      #           "display_name" => "Large box",
      #         }
      #       }
      #     }
      collection_hash = products_bulk_params[:products]
        .transform_values { |product|
          # Convert variants_attributes form hash to an array if present
          product[:variants_attributes] &&= product[:variants_attributes].values
          product
        }.with_indifferent_access
      Sets::ProductSet.new(collection_attributes: collection_hash)
    end

    def products_bulk_params
      params.permit(products: ::PermittedAttributes::Product.attributes)
        .to_h.with_indifferent_access
    end
  end
end
