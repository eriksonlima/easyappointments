<?php defined('BASEPATH') or exit('No direct script access allowed');

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
 * Companies API v1 controller.
 *
 * @package Controllers
 */
class Companies_api_v1 extends EA_Controller
{
    /**
     * Companies_api_v1 constructor.
     */
    public function __construct()
    {
        parent::__construct();

        $this->load->library('api');

        $this->api->auth();

        $this->api->model('companies_model');
    }

    /**
     * Get a company collection.
     */
    public function index(): void
    {
        try {
            $keyword = $this->api->request_keyword();
            $limit = $this->api->request_limit();
            $offset = $this->api->request_offset();
            $order_by = $this->api->request_order_by();
            $fields = $this->api->request_fields();

            $companies = empty($keyword)
                ? $this->companies_model->get(null, $limit, $offset, $order_by)
                : $this->companies_model->search($keyword, $limit, $offset, $order_by);

            foreach ($companies as &$company) {
                $this->companies_model->api_encode($company);

                if (!empty($fields)) {
                    $this->companies_model->only($company, $fields);
                }
            }

            json_response($companies);
        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Get a single company.
     *
     * @param int|null $id Company ID.
     */
    public function show(?int $id = null): void
    {
        try {
            $occurrences = $this->companies_model->get(['id' => $id]);

            if (empty($occurrences)) {
                response('', 404);

                return;
            }

            $fields = $this->api->request_fields();

            $company = $this->companies_model->find($id);

            $this->companies_model->api_encode($company);

            if (!empty($fields)) {
                $this->companies_model->only($company, $fields);
            }

            json_response($company);
        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Store a new company.
     */
    public function store(): void
    {
        try {
            $company = request();

            $this->companies_model->api_decode($company);

            if (array_key_exists('id', $company)) {
                unset($company['id']);
            }

            if (!isset($company['providers'])) {
                $company['providers'] = [];
            }

            $company_id = $this->companies_model->save($company);

            $created_company = $this->companies_model->find($company_id);

            $this->companies_model->api_encode($created_company);

            json_response($created_company, 201);
        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Update a company.
     *
     * @param int $id Company ID.
     */
    public function update(int $id): void
    {
        try {
            $occurrences = $this->companies_model->get(['id' => $id]);

            if (empty($occurrences)) {
                response('', 404);

                return;
            }

            $original_company = $occurrences[0];

            $company = request();

            $this->companies_model->api_decode($company, $original_company);

            $company_id = $this->companies_model->save($company);

            $updated_company = $this->companies_model->find($company_id);

            $this->companies_model->api_encode($updated_company);

            json_response($updated_company);
        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Delete a company.
     *
     * @param int $id Company ID.
     */
    public function destroy(int $id): void
    {
        try {
            $occurrences = $this->companies_model->get(['id' => $id]);

            if (empty($occurrences)) {
                response('', 404);

                return;
            }

            $this->companies_model->delete($id);

            response('', 204);
        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Get the working plan of a provider within a company context.
     *
     * GET /api/v1/companies/{id}/providers/{provider_id}/working_plan
     *
     * @param int $id          Company ID.
     * @param int $provider_id Provider user ID.
     */
    public function provider_working_plan_show(int $id, int $provider_id): void
    {
        try {
            $company_occurrences = $this->companies_model->get(['id' => $id]);

            if (empty($company_occurrences)) {
                response('', 404);

                return;
            }

            $this->load->model('providers_model');

            $provider_occurrences = $this->providers_model->get(['id' => $provider_id]);

            if (empty($provider_occurrences)) {
                response('', 404);

                return;
            }

            $working_plan_json = $this->companies_model->get_provider_working_plan($id, $provider_id);

            if ($working_plan_json === null) {
                $provider = $this->providers_model->find($provider_id);
                $working_plan_json = $provider['settings']['working_plan'] ?? '{}';
            }

            json_response([
                'companyId' => $id,
                'providerId' => $provider_id,
                'workingPlan' => json_decode($working_plan_json, true),
            ]);
        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Set the working plan of a provider within a company context.
     *
     * PUT /api/v1/companies/{id}/providers/{provider_id}/working_plan
     *
     * Body: { "workingPlan": { "monday": { "start": "09:00", "end": "17:00", "breaks": [] }, ... } }
     *
     * @param int $id          Company ID.
     * @param int $provider_id Provider user ID.
     */
    public function provider_working_plan_update(int $id, int $provider_id): void
    {
        try {
            $company_occurrences = $this->companies_model->get(['id' => $id]);

            if (empty($company_occurrences)) {
                response('', 404);

                return;
            }

            $this->load->model('providers_model');

            $provider_occurrences = $this->providers_model->get(['id' => $provider_id]);

            if (empty($provider_occurrences)) {
                response('', 404);

                return;
            }

            $payload = request();

            if (!isset($payload['workingPlan'])) {
                response(json_encode(['error' => 'workingPlan field is required.']), 400);

                return;
            }

            $working_plan_json = json_encode($payload['workingPlan']);

            $this->companies_model->set_provider_working_plan($id, $provider_id, $working_plan_json);

            json_response([
                'companyId' => $id,
                'providerId' => $provider_id,
                'workingPlan' => $payload['workingPlan'],
            ]);
        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Get the working plan of a provider for independent (particular) work.
     *
     * GET /api/v1/companies/providers/{provider_id}/working_plan
     *
     * @param int $provider_id Provider user ID.
     */
    public function provider_particular_working_plan_show(int $provider_id): void
    {
        try {
            $this->load->model('providers_model');

            $provider_occurrences = $this->providers_model->get(['id' => $provider_id]);

            if (empty($provider_occurrences)) {
                response('', 404);

                return;
            }

            $provider = $this->providers_model->find($provider_id);

            $working_plan_json = $provider['settings']['working_plan'] ?? '{}';

            json_response([
                'providerId' => $provider_id,
                'context' => 'particular',
                'workingPlan' => json_decode($working_plan_json, true),
            ]);
        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Set the working plan of a provider for independent (particular) work.
     *
     * PUT /api/v1/companies/providers/{provider_id}/working_plan
     *
     * Body: { "workingPlan": { "monday": { "start": "09:00", "end": "17:00", "breaks": [] }, ... } }
     *
     * @param int $provider_id Provider user ID.
     */
    public function provider_particular_working_plan_update(int $provider_id): void
    {
        try {
            $this->load->model('providers_model');

            $provider_occurrences = $this->providers_model->get(['id' => $provider_id]);

            if (empty($provider_occurrences)) {
                response('', 404);

                return;
            }

            $payload = request();

            if (!isset($payload['workingPlan'])) {
                response(json_encode(['error' => 'workingPlan field is required.']), 400);

                return;
            }

            $provider = $this->providers_model->find($provider_id);

            $provider['settings']['working_plan'] = json_encode($payload['workingPlan']);

            $this->providers_model->save($provider);

            json_response([
                'providerId' => $provider_id,
                'context' => 'particular',
                'workingPlan' => $payload['workingPlan'],
            ]);
        } catch (Throwable $e) {
            json_exception($e);
        }
    }
}
