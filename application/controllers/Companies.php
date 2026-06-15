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
 * Companies controller.
 *
 * Handles company-related operations in the backend panel.
 *
 * @package Controllers
 */
class Companies extends EA_Controller
{
    public array $allowed_company_fields = [
        'id',
        'name',
        'slug',
        'description',
        'address',
        'city',
        'state',
        'zip_code',
        'phone_number',
        'email',
        'notes',
        'logo',
        'timezone',
        'language',
        'is_private',
        'providers',
    ];

    public array $optional_company_fields = [
        'slug' => null,
        'description' => null,
        'address' => null,
        'city' => null,
        'state' => null,
        'zip_code' => null,
        'phone_number' => null,
        'email' => null,
        'notes' => null,
        'logo' => null,
        'timezone' => null,
        'language' => null,
        'is_private' => false,
        'providers' => [],
    ];

    /**
     * Companies constructor.
     */
    public function __construct()
    {
        parent::__construct();

        $this->load->model('companies_model');
        $this->load->model('providers_model');
        $this->load->model('secretaries_model');
        $this->load->model('roles_model');

        $this->load->library('accounts');
        $this->load->library('timezones');
    }

    /**
     * Render the backend companies page.
     */
    public function index(): void
    {
        method('get');

        session(['dest_url' => site_url('companies')]);

        $user_id = session('user_id');

        if (cannot('view', PRIV_COMPANIES)) {
            if ($user_id) {
                abort(403, 'Forbidden');
            }

            redirect('login');

            return;
        }

        $role_slug = session('role_slug');

        $providers = $this->providers_model->get();

        // Build map: company_id → list of secretaries linked to that company.
        $all_companies = $this->companies_model->get();
        $company_secretaries_map = [];
        foreach ($all_companies as $company) {
            $secs = $this->secretaries_model->get_by_company_id((int) $company['id']);
            $company_secretaries_map[(int) $company['id']] = array_map(
                fn($s) => ['id' => (int) $s['id'], 'name' => $s['first_name'] . ' ' . $s['last_name']],
                $secs,
            );
        }

        script_vars([
            'user_id' => $user_id,
            'role_slug' => $role_slug,
            'providers' => filter_sensitive_users_data($providers),
            'company_secretaries_map' => $company_secretaries_map,
        ]);

        html_vars([
            'page_title' => lang('companies'),
            'active_menu' => PRIV_COMPANIES,
            'user_display_name' => $this->accounts->get_user_display_name($user_id),
            'timezones' => $this->timezones->to_array(),
            'privileges' => $this->roles_model->get_permissions_by_slug($role_slug),
            'providers' => filter_sensitive_users_data($providers),
        ]);

        $this->load->view('pages/companies');
    }

    /**
     * Filter companies by the provided keyword.
     */
    public function search(): void
    {
        try {
            method('post');

            if (cannot('view', PRIV_COMPANIES)) {
                abort(403, 'Forbidden');
            }

            check('keyword', 'string|null');
            check('order_by', 'string|null');
            check('limit', 'numeric|null');
            check('offset', 'numeric|null');

            $keyword = request('keyword', '');
            $order_by = request('order_by', 'update_datetime DESC');
            $limit = request('limit', 1000);
            $offset = (int) request('offset', '0');

            $companies = $this->companies_model->search($keyword, $limit, $offset, $order_by);

            foreach ($companies as &$company) {
                $company['providers'] = $this->companies_model->get_provider_ids((int) $company['id']);
            }

            json_response($companies);
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
            method('post');

            if (cannot('add', PRIV_COMPANIES)) {
                abort(403, 'Forbidden');
            }

            check('company', 'array');

            $company = request('company');

            $this->companies_model->only($company, $this->allowed_company_fields);
            $this->companies_model->optional($company, $this->optional_company_fields);

            $company_id = $this->companies_model->save($company);

            json_response([
                'success' => true,
                'id' => $company_id,
            ]);
        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Find a company.
     */
    public function find(): void
    {
        try {
            method('get');

            if (cannot('view', PRIV_COMPANIES)) {
                abort(403, 'Forbidden');
            }

            check('company_id', 'numeric');

            $company_id = (int) request('company_id');

            $company = $this->companies_model->find($company_id);

            json_response($company);
        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Update a company.
     */
    public function update(): void
    {
        try {
            method('post');

            if (cannot('edit', PRIV_COMPANIES)) {
                abort(403, 'Forbidden');
            }

            check('company', 'array');

            $company = request('company');

            $this->companies_model->only($company, $this->allowed_company_fields);
            $this->companies_model->optional($company, $this->optional_company_fields);

            $company_id = $this->companies_model->save($company);

            json_response([
                'success' => true,
                'id' => $company_id,
            ]);
        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Remove a company.
     */
    public function destroy(): void
    {
        try {
            method('post');

            if (cannot('delete', PRIV_COMPANIES)) {
                abort(403, 'Forbidden');
            }

            check('company_id', 'numeric');

            $company_id = (int) request('company_id');

            $this->companies_model->delete($company_id);

            json_response([
                'success' => true,
            ]);
        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Get the working plan of a provider in the context of a company.
     */
    public function get_provider_working_plan(): void
    {
        try {
            method('get');

            if (cannot('view', PRIV_COMPANIES)) {
                abort(403, 'Forbidden');
            }

            check('company_id', 'numeric');
            check('provider_id', 'numeric');

            $company_id = (int) request('company_id');
            $provider_id = (int) request('provider_id');

            $working_plan = $this->companies_model->get_provider_working_plan($company_id, $provider_id);

            json_response([
                'working_plan' => $working_plan ? json_decode($working_plan, true) : null,
            ]);
        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Set the working plan of a provider in the context of a company.
     */
    public function set_provider_working_plan(): void
    {
        try {
            method('post');

            if (cannot('edit', PRIV_COMPANIES)) {
                abort(403, 'Forbidden');
            }

            check('company_id', 'numeric');
            check('provider_id', 'numeric');

            $company_id = (int) request('company_id');
            $provider_id = (int) request('provider_id');

            $working_plan_raw = request('working_plan_json');

            if (empty($working_plan_raw)) {
                throw new InvalidArgumentException('working_plan_json field is required.');
            }

            $working_plan = json_decode($working_plan_raw, true);

            if (!is_array($working_plan)) {
                throw new InvalidArgumentException('working_plan_json must be a valid JSON object.');
            }

            $conflicts = $this->companies_model->find_working_plan_conflicts($provider_id, $working_plan, $company_id);

            if (!empty($conflicts)) {
                json_response(['conflicts' => $conflicts], 422);

                return;
            }

            $this->companies_model->set_provider_working_plan($company_id, $provider_id, $working_plan_raw);

            json_response([
                'success' => true,
            ]);
        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Return all existing working plans for a provider across companies and particular, for display in the modal.
     */
    public function get_provider_all_working_plans(): void
    {
        try {
            method('get');

            if (cannot('view', PRIV_COMPANIES)) {
                abort(403, 'Forbidden');
            }

            check('provider_id', 'numeric');
            check('company_id', 'numeric|null');

            $provider_id = (int) request('provider_id');
            $exclude_company_id = request('company_id') ? (int) request('company_id') : null;

            $plans = $this->companies_model->get_all_provider_working_plans($provider_id, $exclude_company_id);

            json_response($plans);
        } catch (Throwable $e) {
            json_exception($e);
        }
    }
}
