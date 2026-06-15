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

class Migration_Create_company_admins_table extends EA_Migration
{
    /**
     * Upgrade method.
     */
    public function up(): void
    {
        if (!$this->db->table_exists('company_admins')) {
            $this->dbforge->add_field([
                'id_companies' => [
                    'type' => 'BIGINT',
                    'constraint' => '20',
                    'unsigned' => true,
                    'null' => false,
                ],
                'id_users_admin' => [
                    'type' => 'INT',
                    'constraint' => '11',
                    'null' => false,
                ],
            ]);

            $this->dbforge->add_key(['id_companies', 'id_users_admin'], true);
            $this->dbforge->add_key('id_companies');
            $this->dbforge->add_key('id_users_admin');

            $this->dbforge->create_table('company_admins', true, ['engine' => 'InnoDB']);

            $this->db->query(
                '
                ALTER TABLE `' .
                    $this->db->dbprefix('company_admins') .
                    '`
                    ADD CONSTRAINT `company_admins_companies` FOREIGN KEY (`id_companies`) REFERENCES `' .
                    $this->db->dbprefix('companies') .
                    '` (`id`)
                    ON DELETE CASCADE
                    ON UPDATE CASCADE
            ',
            );

            $this->db->query(
                '
                ALTER TABLE `' .
                    $this->db->dbprefix('company_admins') .
                    '`
                    ADD CONSTRAINT `company_admins_users_admin` FOREIGN KEY (`id_users_admin`) REFERENCES `' .
                    $this->db->dbprefix('users') .
                    '` (`id`)
                    ON DELETE CASCADE
                    ON UPDATE CASCADE
            ',
            );
        }
    }

    /**
     * Downgrade method.
     */
    public function down(): void
    {
        if ($this->db->table_exists('company_admins')) {
            $this->db->query(
                'ALTER TABLE `' .
                    $this->db->dbprefix('company_admins') .
                    '` DROP FOREIGN KEY `company_admins_companies`',
            );

            $this->db->query(
                'ALTER TABLE `' .
                    $this->db->dbprefix('company_admins') .
                    '` DROP FOREIGN KEY `company_admins_users_admin`',
            );

            $this->dbforge->drop_table('company_admins');
        }
    }
}
