/* ----------------------------------------------------------------------------
 * Easy!Appointments - Online Appointment Scheduler
 *
 * @package     EasyAppointments
 * @author      A.Tselegidis <alextselegidis@gmail.com>
 * @copyright   Copyright (c) Alex Tselegidis
 * @license     https://opensource.org/licenses/GPL-3.0 - GPLv3
 * @link        https://easyappointments.org
 * @since       v1.6.0
 * ---------------------------------------------------------------------------- */

/**
 * Companies HTTP client.
 *
 * This module implements the companies related HTTP requests.
 */
App.Http.Companies = (function () {
    /**
     * Save (create or update) a company.
     *
     * @param {Object} company
     *
     * @return {Object}
     */
    function save(company) {
        return company.id ? update(company) : store(company);
    }

    /**
     * Create a company.
     *
     * @param {Object} company
     *
     * @return {Object}
     */
    function store(company) {
        const url = App.Utils.Url.siteUrl('companies/store');

        const data = {
            csrf_token: vars('csrf_token'),
            company,
        };

        return $.post(url, data);
    }

    /**
     * Update a company.
     *
     * @param {Object} company
     *
     * @return {Object}
     */
    function update(company) {
        const url = App.Utils.Url.siteUrl('companies/update');

        const data = {
            csrf_token: vars('csrf_token'),
            company,
        };

        return $.post(url, data);
    }

    /**
     * Delete a company.
     *
     * @param {Number} companyId
     *
     * @return {Object}
     */
    function destroy(companyId) {
        const url = App.Utils.Url.siteUrl('companies/destroy');

        const data = {
            csrf_token: vars('csrf_token'),
            company_id: companyId,
        };

        return $.post(url, data);
    }

    /**
     * Search companies by keyword.
     *
     * @param {String} keyword
     * @param {Number} [limit]
     * @param {Number} [offset]
     * @param {String} [orderBy]
     *
     * @return {Object}
     */
    function search(keyword, limit = null, offset = null, orderBy = null) {
        const url = App.Utils.Url.siteUrl('companies/search');

        const data = {
            csrf_token: vars('csrf_token'),
            keyword,
            limit,
            offset,
            order_by: orderBy || undefined,
        };

        return $.post(url, data);
    }

    /**
     * Find a company.
     *
     * @param {Number} companyId
     *
     * @return {Object}
     */
    function find(companyId) {
        const url = App.Utils.Url.siteUrl('companies/find');

        const data = {
            csrf_token: vars('csrf_token'),
            company_id: companyId,
        };

        return $.get(url, data);
    }

    /**
     * Get provider working plan within a company context.
     *
     * @param {Number} companyId
     * @param {Number} providerId
     *
     * @return {Object}
     */
    function getProviderWorkingPlan(companyId, providerId) {
        const url = App.Utils.Url.siteUrl('companies/get_provider_working_plan');

        const data = {
            csrf_token: vars('csrf_token'),
            company_id: companyId,
            provider_id: providerId,
        };

        return $.get(url, data);
    }

    /**
     * Set provider working plan within a company context.
     *
     * @param {Number} companyId
     * @param {Number} providerId
     * @param {Object} workingPlan
     *
     * @return {Object}
     */
    function setProviderWorkingPlan(companyId, providerId, workingPlan) {
        const url = App.Utils.Url.siteUrl('companies/set_provider_working_plan');

        const data = {
            csrf_token: vars('csrf_token'),
            company_id: companyId,
            provider_id: providerId,
            working_plan_json: JSON.stringify(workingPlan),
        };

        return $.post(url, data);
    }

    /**
     * Get all working plans for a provider (for conflict display in the modal).
     *
     * @param {Number} providerId
     * @param {Number|null} excludeCompanyId
     *
     * @return {Object}
     */
    function getProviderAllWorkingPlans(providerId, excludeCompanyId = null) {
        const url = App.Utils.Url.siteUrl('companies/get_provider_all_working_plans');

        const data = {
            csrf_token: vars('csrf_token'),
            provider_id: providerId,
            company_id: excludeCompanyId || undefined,
        };

        return $.get(url, data);
    }

    return {
        save,
        store,
        update,
        destroy,
        search,
        find,
        getProviderWorkingPlan,
        setProviderWorkingPlan,
        getProviderAllWorkingPlans,
    };
})();
