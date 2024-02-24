#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import logging
_logger = logging.getLogger(__name__)

REPOSITORIES = '/opt/odoo/src'
ODOO_PATH = '/opt/odoo/odoo'
ENTERPRISE_PATH = '/opt/odoo/enterprise'

addons = []

if os.path.isdir(ODOO_PATH):
    addons.append(os.path.join(ODOO_PATH, 'addons'))
    addons.append(os.path.join(ODOO_PATH, 'odoo', 'addons'))

if os.path.isdir(ENTERPRISE_PATH):
    addons.insert(0, os.path.join(ENTERPRISE_PATH))

repo_addons = [
    os.path.join(REPOSITORIES, d)
    for d in sorted(os.listdir(REPOSITORIES))
    if os.path.isdir(os.path.join(REPOSITORIES, d))
]

# Repo addons are preprended, in case we want to overwrite odoo modules
addons = repo_addons + addons

# Overwrite 10-addons.conf
_logger.debug('Updating addons_path.. %s' % addons)
with open('/opt/odoo/odoo.conf', 'r+') as file:
    lines = file.readlines()
    lines[1] = 'addons_path = %s\n' % ','.join(addons)

with open('/opt/odoo/odoo.conf', 'w+') as file:
    file.writelines(lines)
